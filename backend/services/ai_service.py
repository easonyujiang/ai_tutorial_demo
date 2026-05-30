import base64
import json
import os
import subprocess
import tempfile

from openai import OpenAI

from config import settings
from models.tutorial import TutorialStep
from infrastructure.logger import get_logger

logger = get_logger(__name__)

SYSTEM_PROMPT = """你是一个视频教程分析助手。你会收到从视频中提取的一系列关键帧截图（按时间顺序排列），请根据这些截图分析视频中的操作步骤。

请按以下 JSON 格式输出分析结果：
{
  "title": "教程标题（简洁描述视频中的操作内容）",
  "steps": [
    {
      "instruction": "这一步的具体操作说明文字",
      "target_text": "当前步骤中用户需要点击或查找的精确按钮/文字",
      "page_description": "当前步骤所在的页面场景描述"
    }
  ]
}

规则：
1. instruction 描述用户需要做什么操作
2. target_text 必须是该步骤中用户需要点击的精确文字（按钮名、菜单项名等）
3. page_description 描述该步骤发生的页面场景（如"手机桌面主屏幕"、"设置页面"）
4. 拆分 3~8 个关键步骤
5. 只返回 JSON，不要有任何其他文字"""

MAX_FRAMES = 8
COMPRESS_HEIGHT = 480
COMPRESS_FPS = 8
COMPRESS_CRF = 28
COMPRESS_PRESET = "fast"
EXTRACT_FRAME_HEIGHT = 1080


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
    duration = float(result.stdout.strip())
    logger.debug("Video duration: %.1fs", duration)
    return duration


def _compress_video(input_path: str) -> str:
    import uuid

    compressed_dir = os.path.join(tempfile.gettempdir(), "tutorial_compress")
    os.makedirs(compressed_dir, exist_ok=True)
    output_path = os.path.join(compressed_dir, f"compressed_{uuid.uuid4().hex}.mp4")

    logger.info(
        "Compressing video: %s -> %s (scale=%dp, fps=%d, crf=%d)",
        os.path.basename(input_path),
        os.path.basename(output_path),
        COMPRESS_HEIGHT,
        COMPRESS_FPS,
        COMPRESS_CRF,
    )

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

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    logger.info("Video compressed: %.1fMB", size_mb)
    return output_path


def _extract_frames(video_path: str) -> list[bytes]:
    duration = _get_video_duration(video_path)
    frame_count = min(MAX_FRAMES, max(3, int(duration / 3)))

    logger.info("Extracting %d frames from video...", frame_count)

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
                    "-vf", f"scale={EXTRACT_FRAME_HEIGHT}:-2",
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
            logger.debug("Frame %d/%d extracted at %.1fs, size=%d bytes",
                         i + 1, frame_count, t, len(frame_data))
    finally:
        try:
            os.rmdir(tmp_dir)
        except OSError:
            pass

    logger.info("Frames extracted: %d total", len(frames))
    return frames


def analyze_video(video_path: str) -> tuple[str, list[dict]]:
    api_key = settings.openai_api_key or os.getenv("OPENAI_API_KEY")
    base_url = settings.openai_base_url or os.getenv("OPENAI_BASE_URL")
    model = settings.openai_model or os.getenv("OPENAI_MODEL", "gpt-4o")

    if not api_key:
        raise RuntimeError("OPENAI_API_KEY 环境变量未设置")
    if not base_url:
        raise RuntimeError("OPENAI_BASE_URL 环境变量未设置")

    logger.info("AI analysis starting (model=%s)", model)
    client = OpenAI(api_key=api_key, base_url=base_url)

    work_path = video_path
    try:
        work_path = _compress_video(video_path)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"视频压缩失败：{e.stderr}")

    frames = _extract_frames(work_path)

    image_parts = []
    total_size = 0
    for frame_data in frames:
        b64 = base64.b64encode(frame_data).decode("utf-8")
        total_size += len(b64)
        image_parts.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{b64}",
                "detail": "low",
            },
        })

    logger.info("Sending %d frames to API (total base64 size: %d chars)...",
                len(frames), total_size)

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
        logger.error("API call failed: %s", e)
        raise RuntimeError(f"API 调用失败：{e}")

    if response.usage:
        logger.info(
            "API response: prompt=%d completion=%d total=%d tokens",
            response.usage.prompt_tokens,
            response.usage.completion_tokens,
            response.usage.total_tokens,
        )

    raw = response.choices[0].message.content
    if not raw:
        raise RuntimeError("模型返回了空内容")

    logger.debug("Raw API response (first 500 chars): %s", raw[:500])

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        decoder = json.JSONDecoder()
        try:
            data, _ = decoder.raw_decode(raw)
        except json.JSONDecodeError as e:
            logger.error("Failed to parse API response as JSON: %s", e)
            raise RuntimeError(f"模型返回的数据不是有效的 JSON：{e}\n原始内容：{raw}")

    title = str(data.get("title", "未命名教程"))
    steps_data = data.get("steps")
    if not isinstance(steps_data, list) or len(steps_data) == 0:
        raise RuntimeError(f"模型返回的 steps 为空或格式不正确：{raw}")

    steps = []
    for i, step in enumerate(steps_data):
        steps.append({
            "instruction": str(step.get("instruction", f"步骤 {i + 1}")),
            "target_text": str(step.get("target_text", "")),
            "page_description": str(step.get("page_description", "")),
        })

    logger.info(
        "AI analysis complete: title='%s', steps=%d",
        title, len(steps),
    )
    for i, s in enumerate(steps):
        logger.debug(
            "  Step %d: target='%s', page='%s'",
            i, s["target_text"], s["page_description"],
        )

    return title, steps
