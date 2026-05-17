import base64
import json
import os
import subprocess
import tempfile

from openai import OpenAI

from models.tutorial import TutorialResponse, StepModel, RectModel

SYSTEM_PROMPT = """你是一个视频教程分析助手。你会收到从视频中提取的一系列关键帧截图（按时间顺序排列），请根据这些截图分析视频中的操作步骤。

请按以下 JSON 格式输出分析结果：
{
  "title": "教程标题（简洁描述视频中的操作内容）",
  "steps": [
    {
      "instruction": "这一步的具体操作说明文字",
      "rect": {"left": 0.0, "top": 0.0, "width": 0.0, "height": 0.0},
      "bubble_dir": "bottom"
    }
  ]
}

注意：
1. rect 中的 left、top、width、height 都是相对于视频画面的比例值，取值范围 0~1
2. bubble_dir 只能是 "top"、"bottom"、"left"、"right" 之一
3. 根据截图内容提炼 3~8 个关键步骤
4. 每个步骤的 rect 应该标注当前操作发生的主要区域
5. 确保所有数值在合理范围内
6. 只返回 JSON，不要有任何其他文字"""

MAX_FRAMES = 8

COMPRESS_HEIGHT = 480
COMPRESS_FPS = 8
COMPRESS_CRF = 28
COMPRESS_PRESET = "fast"


def _get_video_duration(input_path: str) -> float:
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            input_path,
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return float(result.stdout.strip())


def _compress_video(input_path: str) -> str:
    import uuid
    compressed_dir = os.path.join(tempfile.gettempdir(), "tutorial_compress")
    os.makedirs(compressed_dir, exist_ok=True)
    output_path = os.path.join(compressed_dir, f"compressed_{uuid.uuid4().hex}.mp4")

    subprocess.run(
        [
            "ffmpeg", "-y",
            "-i", input_path,
            "-vf", f"scale=-2:{COMPRESS_HEIGHT},fps={COMPRESS_FPS}",
            "-c:v", "libx264",
            "-crf", str(COMPRESS_CRF),
            "-preset", COMPRESS_PRESET,
            "-an",
            "-movflags", "+faststart",
            output_path,
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    return output_path


def _extract_frames(video_path: str) -> list[bytes]:
    duration = _get_video_duration(video_path)
    frame_count = min(MAX_FRAMES, max(3, int(duration / 3)))

    frames = []
    tmp_dir = tempfile.mkdtemp()

    try:
        interval = duration / (frame_count + 1)
        for i in range(frame_count):
            t = interval * (i + 1)
            output_file = os.path.join(tmp_dir, f"frame_{i:03d}.jpg")
            subprocess.run(
                [
                    "ffmpeg", "-y",
                    "-ss", str(t),
                    "-i", video_path,
                    "-vframes", "1",
                    "-q:v", "3",
                    "-vf", "scale=720:-2",
                    output_file,
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            with open(output_file, "rb") as f:
                frame_data = f.read()
            frames.append(frame_data)
            os.remove(output_file)
    finally:
        try:
            os.rmdir(tmp_dir)
        except OSError:
            pass

    return frames


def analyze_video(video_path: str, compress: bool = True) -> TutorialResponse:
    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")
    model = os.getenv("OPENAI_MODEL", "gpt-5.5")

    if not api_key:
        raise RuntimeError("OPENAI_API_KEY 环境变量未设置")
    if not base_url:
        raise RuntimeError("OPENAI_BASE_URL 环境变量未设置")

    client = OpenAI(api_key=api_key, base_url=base_url)

    work_path = video_path
    try:
        if compress:
            work_path = _compress_video(video_path)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"视频压缩失败：{e.stderr}")

    frames = _extract_frames(work_path)

    image_parts = []
    for i, frame_data in enumerate(frames):
        b64 = base64.b64encode(frame_data).decode("utf-8")
        image_parts.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{b64}",
                "detail": "low",
            },
        })

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        *image_parts,
                        {
                            "type": "text",
                            "text": "以上是按时间顺序从视频中提取的关键帧截图，请分析其中的操作步骤，并按照系统提示中的 JSON 格式输出结果。",
                        },
                    ],
                },
            ],
            response_format={"type": "json_object"},
            max_tokens=4096,
        )
    except Exception as e:
        raise RuntimeError(f"API 调用失败：{e}")

    if not hasattr(response, "choices"):
        raise RuntimeError(f"API 返回了意外的数据类型（{type(response).__name__}）：{str(response)[:500]}")

    raw = response.choices[0].message.content
    if not raw:
        raise RuntimeError("模型返回了空内容")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"模型返回的数据不是有效的 JSON：{e}\n原始内容：{raw}")

    title = str(data.get("title", "未命名教程"))
    steps_data = data.get("steps")
    if not isinstance(steps_data, list) or len(steps_data) == 0:
        raise RuntimeError(f"模型返回的 steps 为空或格式不正确：{raw}")

    steps = []
    for i, step in enumerate(steps_data):
        instruction = str(step.get("instruction", f"步骤 {i + 1}"))
        rect_data = step.get("rect", {})
        rect = RectModel(
            left=float(rect_data.get("left", 0.05)),
            top=float(rect_data.get("top", 0.22)),
            width=float(rect_data.get("width", 0.9)),
            height=float(rect_data.get("height", 0.08)),
        )
        bubble_dir = str(step.get("bubble_dir", "bottom"))
        if bubble_dir not in ("top", "bottom", "left", "right"):
            bubble_dir = "bottom"

        steps.append(
            StepModel(
                image="",
                instruction=instruction,
                rect=rect,
                bubble_dir=bubble_dir,
            )
        )

    return TutorialResponse(
        id="local_guide",
        title=title,
        steps=steps,
    )
