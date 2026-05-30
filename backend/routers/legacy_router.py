import asyncio

from fastapi import APIRouter, HTTPException

from infrastructure.logger import get_logger
from services.video_service import (
    detect_platform,
    extract_url,
    resolve_short_url,
    download_video,
)
from services.ai_service import analyze_video as ai_analyze
from models.tutorial import TutorialSession, SessionStatus

logger = get_logger(__name__)

router = APIRouter()


@router.get("/api/video-info")
async def video_info(url: str):
    try:
        pure_url = extract_url(url)
        platform = detect_platform(pure_url)
        resolved = resolve_short_url(pure_url)
        return {"title": resolved, "platform": platform}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"无法获取视频信息：{e}")


@router.post("/api/analyze")
async def analyze_video(request: dict):
    url = request.get("url", "").strip()
    if not url:
        raise HTTPException(status_code=400, detail="请输入视频链接")

    session_id = "legacy_direct"

    try:
        pure = extract_url(url)
        platform = detect_platform(pure)
        video_url = resolve_short_url(pure)

        video_path = await asyncio.to_thread(download_video, video_url, session_id)
        result = await asyncio.to_thread(ai_analyze, video_path)
        title = result["title"]
        steps_data = result["steps"]

        steps = [
            {
                "image": "",
                "instruction": s["instruction"],
                "target_text": s.get("target_text", ""),
                "target_type": s.get("target_type", "text"),
                "target_description": s.get("target_description", ""),
                "page_description": s.get("page_description", ""),
                "rect": {
                    "left": 0.05 + (i * 0.05),
                    "top": 0.22 + (i * 0.15),
                    "width": 0.9,
                    "height": 0.08,
                },
                "bubble_dir": "bottom" if i % 2 == 0 else "left",
            }
            for i, s in enumerate(steps_data)
        ]

        _cleanup_temp_files(session_id)

        return {"id": session_id, "title": title, "steps": steps}
    except Exception as e:
        logger.error("analyze_video error: %s", e)
        _cleanup_temp_files(session_id)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/tutorial-template")
async def tutorial_template(request: dict):
    title = request.get("title", "").strip()
    if not title:
        raise HTTPException(status_code=400, detail="请输入教程标题")

    return {
        "id": "template_guide",
        "title": title,
        "steps": [
            {
                "image": "",
                "instruction": f"欢迎观看「{title}」，请点击这里开始第一步",
                "rect": {"left": 0.05, "top": 0.22, "width": 0.9, "height": 0.08},
                "bubble_dir": "bottom",
            },
            {
                "image": "",
                "instruction": f"根据「{title}」的演示内容，请关注这个关键操作区域",
                "rect": {"left": 0.68, "top": 0.38, "width": 0.25, "height": 0.1},
                "bubble_dir": "left",
            },
            {
                "image": "",
                "instruction": f"完成「{title}」中的最后一步后，请点击这里结束教程",
                "rect": {"left": 0.08, "top": 0.66, "width": 0.84, "height": 0.08},
                "bubble_dir": "top",
            },
        ],
    }


def _cleanup_temp_files(session_id: str):
    import os
    import tempfile
    import shutil

    download_dir = os.path.join(tempfile.gettempdir(), "tutorial_downloads", session_id)
    if os.path.exists(download_dir):
        shutil.rmtree(download_dir, ignore_errors=True)
