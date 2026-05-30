import base64
import json
import os
import subprocess
import tempfile

from openai import OpenAI

from config import settings
from infrastructure.logger import get_logger

logger = get_logger(__name__)

SYSTEM_PROMPT = """你是一个视频教程分析助手。你会收到从视频中提取的一系列关键帧截图（按时间顺序排列），请根据这些截图分析视频中的操作步骤。

请按以下 JSON 格式输出分析结果：
{
  "title": "教程标题（简洁描述视频中的操作内容）",
  "app_name": "目标应用名称（如：微信、设置、相机），如果无法确定则留空",
  "app_package": "目标应用可能的 Android 包名（如：com.android.settings），如果无法确定则留空",
  "steps": [
    {
      "instruction": "这一步的具体操作说明文字",
      "target_text": "当前步骤中用户需要点击或查找的精确按钮文字（纯文字按钮填写文字，无文字则留空）",
      "target_type": "text 或 icon",
      "target_description": "如果目标是图标/按钮（如右上角三个点、齿轮图标、分享箭头），用中文描述其外观和位置",
      "page_description": "当前步骤所在的页面场景描述"
    }
  ]
}

规则：
1. instruction 描述用户需要做什么操作
2. target_text 仅对纯文字按钮填写精确文字（如"设置""确定"）；图标型按钮留空
3. target_type 为 "text" 表示文字按钮，为 "icon" 表示图标/非文字按钮
4. target_description 对图标型目标必填：描述外观+位置（如"右上角三个竖排圆点""底部导航栏中间+号""顶部搜索放大镜图标"）
5. page_description 描述该步骤发生的页面场景（如"手机桌面主屏幕""微信聊天列表"）
6. 拆分 3~8 个关键步骤
7. 只返回 JSON，不要有任何其他文字"""

MAX_FRAMES = 8
COMPRESS_HEIGHT = 480
COMPRESS_FPS = 8
COMPRESS_CRF = 28
COMPRESS_PRESET = "fast"
EXTRACT_FRAME_HEIGHT = 1080


def _is_placeholder_api_key(api_key: str) -> bool:
    k = (api_key or "").strip().lower()
    if not k:
        return True
    return "your-api-key" in k or k == "sk-your-api-key-here"


def _demo_analysis(reason: str = "") -> dict:
    suffix = f"（演示模式：{reason}）" if reason else "（演示模式）"
    return {
        "title": f"示例教程{suffix}",
        "app_name": "",
        "app_package": "",
        "steps": [
            {
                "instruction": "打开目标应用或回到需要操作的页面",
                "target_text": "",
                "target_type": "icon",
                "target_description": "无（演示步骤）",
                "page_description": "任意页面",
            },
            {
                "instruction": "按照教程提示找到对应按钮并点击",
                "target_text": "",
                "target_type": "icon",
                "target_description": "无（演示步骤）",
                "page_description": "任意页面",
            },
            {
                "instruction": "完成操作后返回本应用继续下一步",
                "target_text": "",
                "target_type": "icon",
                "target_description": "无（演示步骤）",
                "page_description": "任意页面",
            },
        ],
    }


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


def analyze_video(video_path: str) -> dict:
    api_key = settings.openai_api_key or os.getenv("OPENAI_API_KEY")
    base_url = settings.openai_base_url or os.getenv("OPENAI_BASE_URL")
    model = settings.openai_model or os.getenv("OPENAI_MODEL", "gpt-4o")

    if _is_placeholder_api_key(api_key):
        logger.warning("OPENAI_API_KEY 未配置或为占位符，启用演示分析")
        return _demo_analysis("未配置模型 API Key")
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
        return _demo_analysis(f"模型请求失败：{e}")

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
    app_name = str(data.get("app_name", ""))
    app_package = str(data.get("app_package", ""))
    steps_data = data.get("steps")
    if not isinstance(steps_data, list) or len(steps_data) == 0:
        raise RuntimeError(f"模型返回的 steps 为空或格式不正确：{raw}")

    steps = []
    for i, step in enumerate(steps_data):
        ttype = str(step.get("target_type", "text"))
        if ttype not in ("text", "icon"):
            ttype = "text" if step.get("target_text", "").strip() else "icon"
        steps.append({
            "instruction": str(step.get("instruction", f"步骤 {i + 1}")),
            "target_text": str(step.get("target_text", "")),
            "target_type": ttype,
            "target_description": str(step.get("target_description", "")),
            "page_description": str(step.get("page_description", "")),
        })

    logger.info(
        "AI analysis complete: title='%s' app='%s' steps=%d",
        title, app_name, len(steps),
    )
    for i, s in enumerate(steps):
        logger.debug(
            "  Step %d: type=%s target='%s' desc='%s' page='%s'",
            i, s["target_type"], s["target_text"], s["target_description"], s["page_description"],
        )

    return {
        "title": title,
        "app_name": app_name,
        "app_package": app_package,
        "steps": steps,
    }
