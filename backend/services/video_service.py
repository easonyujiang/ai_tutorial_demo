import os
import re
import tempfile

import yt_dlp

from config import settings
from infrastructure.logger import get_logger

logger = get_logger(__name__)

PLATFORM_DOUYIN = "douyin"
PLATFORM_BILIBILI = "bilibili"
PLATFORM_YOUTUBE = "youtube"
PLATFORM_UNKNOWN = "unknown"

_DOUYIN_DOMAINS = ("douyin.com", "v.douyin.com", "tiktok.com")
_BILIBILI_DOMAINS = ("bilibili.com", "b23.tv")
_YOUTUBE_DOMAINS = ("youtube.com", "youtu.be")


def detect_platform(raw: str) -> str:
    lower = raw.lower()
    for d in _DOUYIN_DOMAINS:
        if d in lower:
            return PLATFORM_DOUYIN
    for d in _BILIBILI_DOMAINS:
        if d in lower:
            return PLATFORM_BILIBILI
    for d in _YOUTUBE_DOMAINS:
        if d in lower:
            return PLATFORM_YOUTUBE
    return PLATFORM_UNKNOWN


def extract_url(raw_text: str) -> str:
    match = re.search(r"https?://[\w\-./?=&#:%]+", raw_text)
    if match:
        return match.group(0)
    return raw_text.strip()


def resolve_short_url(raw_url: str) -> str:
    platform = detect_platform(raw_url)

    if platform == PLATFORM_UNKNOWN:
        logger.debug("Unknown platform, using raw URL")
        return raw_url

    logger.info("Resolving short URL (platform=%s): %s", platform, raw_url[:80])

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extract_flat": False,
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(raw_url, download=False)
            webpage_url = info.get("webpage_url")
            if webpage_url:
                logger.info("Short URL resolved: %s", webpage_url[:80])
                return webpage_url
    except Exception as e:
        logger.warning("Failed to resolve short URL: %s", e)

    return raw_url


def _build_download_options(output_path: str, platform: str) -> dict:
    base = {
        "outtmpl": output_path,
        "merge_output_format": "mp4",
        "quiet": True,
        "no_warnings": True,
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        },
        "retries": 3,
        "fragment_retries": 3,
        "retry_sleep_functions": {"fragment": lambda n: 3},
        "socket_timeout": 30,
    }

    if platform == PLATFORM_DOUYIN:
        base["format"] = "best[height<=720][ext=mp4]/best[height<=720]/best"
        base["extractor_args"] = {
            "douyin": {"get_all_webpage_formats": ["true"]},
        }
    else:
        base["format"] = (
            "best[height<=720][ext=mp4]/best[height<=720]/best"
        )

    return base


def download_video(url: str, session_id: str) -> str:
    download_dir = os.path.join(
        tempfile.gettempdir(), "tutorial_downloads", session_id
    )
    os.makedirs(download_dir, exist_ok=True)

    output_path = os.path.join(download_dir, "video.mp4")
    platform = detect_platform(url)

    logger.info(
        "Downloading video: platform=%s, session=%s",
        platform, session_id,
    )

    ydl_opts = _build_download_options(output_path, platform)

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
    except Exception as e:
        import shutil
        shutil.rmtree(download_dir, ignore_errors=True)
        logger.error("Video download failed: %s", e)
        raise RuntimeError(f"视频下载失败：{e}")

    if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
        import shutil
        shutil.rmtree(download_dir, ignore_errors=True)
        raise RuntimeError("视频下载失败：输出文件为空")

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    logger.info("Video downloaded: %s (%.1fMB)", output_path, size_mb)
    return output_path
