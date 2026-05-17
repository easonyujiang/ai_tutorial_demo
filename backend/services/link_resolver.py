import os
import re

import yt_dlp

_PLATFORM_DOUYIN = "douyin"
_PLATFORM_BILIBILI = "bilibili"
_PLATFORM_YOUTUBE = "youtube"
_PLATFORM_UNKNOWN = "unknown"

_DOUYIN_DOMAINS = ("douyin.com", "v.douyin.com", "tiktok.com")
_BILIBILI_DOMAINS = ("bilibili.com", "b23.tv")
_YOUTUBE_DOMAINS = ("youtube.com", "youtu.be")


def detect_platform(raw: str) -> str:
    lower = raw.lower()
    for d in _DOUYIN_DOMAINS:
        if d in lower:
            return _PLATFORM_DOUYIN
    for d in _BILIBILI_DOMAINS:
        if d in lower:
            return _PLATFORM_BILIBILI
    for d in _YOUTUBE_DOMAINS:
        if d in lower:
            return _PLATFORM_YOUTUBE
    return _PLATFORM_UNKNOWN


def extract_douyin_url(raw_text: str) -> str:
    match = re.search(r"https?://[\w\-./?=&#:%]+", raw_text)
    if match:
        return match.group(0)
    return raw_text.strip()


def _load_cookies() -> str | None:
    path = os.getenv("DOUYIN_COOKIES_PATH")
    if path and os.path.exists(path):
        return path
    return None


def build_download_options(output_path: str, platform: str) -> dict:
    base = {
        "outtmpl": output_path,
        "merge_output_format": "mp4",
        "quiet": True,
        "no_warnings": True,
    }

    if platform == _PLATFORM_DOUYIN:
        base["format"] = "best[height<=720][ext=mp4]/best[height<=720]/best"
        base["extractor_args"] = {
            "douyin": {"get_all_webpage_formats": ["true"]},
        }
        cookies = _load_cookies()
        if cookies:
            base["cookiefile"] = cookies

    elif platform == _PLATFORM_BILIBILI:
        base["format"] = "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]/best"

    else:
        base["format"] = "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]/best"

    return base


def resolve_real_url(raw_url: str) -> str:
    platform = detect_platform(raw_url)
    if platform == _PLATFORM_DOUYIN:
        return raw_url

    if platform == _PLATFORM_UNKNOWN:
        return raw_url

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extract_flat": False,
    }

    cookies = _load_cookies()
    if cookies and platform == _PLATFORM_DOUYIN:
        ydl_opts["cookiefile"] = cookies

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(raw_url, download=False)
            webpage_url = info.get("webpage_url")
            if webpage_url:
                return webpage_url
    except Exception:
        pass

    return raw_url


def resolve_douyin_short(raw_url: str) -> str | None:
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extract_flat": False,
    }
    cookies = _load_cookies()
    if cookies:
        ydl_opts["cookiefile"] = cookies

    candidates = [raw_url]
    match = re.search(r"https?://[\w\-./?=&#:%]+", raw_url)
    if match and match.group(0) != raw_url.strip():
        candidates.insert(0, match.group(0))

    for url in candidates:
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                result = info.get("webpage_url") or info.get("original_url") or url
                return result
        except Exception:
            continue

    return raw_url
