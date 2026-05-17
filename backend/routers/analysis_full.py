import os
import uuid
import tempfile

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import yt_dlp

from models.tutorial import TutorialResponse
from services.ai_service import analyze_video as run_ai_analysis
from services.link_resolver import (
    detect_platform,
    extract_douyin_url,
    resolve_douyin_short,
    build_download_options,
)

router = APIRouter()

TEMP_DIR = "temp_downloads"
os.makedirs(TEMP_DIR, exist_ok=True)

PLATFORM_DOUYIN = "douyin"
PLATFORM_BILIBILI = "bilibili"
PLATFORM_YOUTUBE = "youtube"


class AnalyzeUrlRequest(BaseModel):
    url: str


def _resolve_input(raw_input: str) -> str:
    platform = detect_platform(raw_input)

    if platform == PLATFORM_DOUYIN:
        pure_url = extract_douyin_url(raw_input)
        return resolve_douyin_short(pure_url)

    return raw_input.strip()


def _download_video(url: str, platform: str, output_dir: str) -> str:
    output_path = os.path.join(output_dir, "video.mp4")

    ydl_opts = build_download_options(output_path, platform)

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
    except Exception as e:
        import shutil
        shutil.rmtree(output_dir, ignore_errors=True)
        raise HTTPException(status_code=400, detail=f"视频下载失败：{e}")

    if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
        import shutil
        shutil.rmtree(output_dir, ignore_errors=True)
        raise HTTPException(status_code=400, detail="视频下载失败：输出文件为空")

    return output_path


@router.post("/api/analyze-full", response_model=TutorialResponse)
async def analyze_full(request: AnalyzeUrlRequest):
    raw_input = request.url.strip()
    if not raw_input:
        raise HTTPException(status_code=400, detail="请输入视频链接或口令")

    video_url = _resolve_input(raw_input)
    platform = detect_platform(video_url)

    unique_id = uuid.uuid4().hex
    output_dir = os.path.join(TEMP_DIR, unique_id)
    os.makedirs(output_dir, exist_ok=True)

    video_path = None
    try:
        video_path = _download_video(video_url, platform, output_dir)
        result = run_ai_analysis(video_path, compress=True)
        return result
    except HTTPException:
        raise
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"分析失败：{e}")
    finally:
        if output_dir and os.path.exists(output_dir):
            import shutil
            shutil.rmtree(output_dir, ignore_errors=True)
