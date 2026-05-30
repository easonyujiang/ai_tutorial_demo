import asyncio
import os
import shutil
import tempfile
import uuid

from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel

from models.skill import Skill, get_skill_store
from services.video_service import extract_url, detect_platform, resolve_short_url, download_video
from services.ai_service import analyze_video as ai_analyze
from infrastructure.logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/api/skills", tags=["skills"])


class AnalyzeRequest(BaseModel):
    url: str


class AnalyzeResponse(BaseModel):
    title: str
    steps: list[dict]


@router.get("")
async def list_skills():
    store = get_skill_store()
    return store.list_all()


@router.get("/{skill_id}")
async def get_skill(skill_id: str):
    store = get_skill_store()
    skill = store.get(skill_id)
    if not skill:
        raise HTTPException(status_code=404, detail="技能不存在")
    return skill


@router.post("", status_code=201)
async def create_skill(skill: Skill):
    store = get_skill_store()
    created = store.create(skill)
    logger.info("Skill created: %s - %s", created.id, created.title)
    return created


@router.put("/{skill_id}")
async def update_skill(skill_id: str, skill: Skill):
    store = get_skill_store()
    updated = store.update(skill_id, skill)
    if not updated:
        raise HTTPException(status_code=404, detail="技能不存在")
    logger.info("Skill updated: %s - %s", skill_id, skill.title)
    return updated


@router.delete("/{skill_id}")
async def delete_skill(skill_id: str):
    store = get_skill_store()
    if not store.delete(skill_id):
        raise HTTPException(status_code=404, detail="技能不存在")
    logger.info("Skill deleted: %s", skill_id)
    return {"ok": True}


@router.post("/analyze")
async def analyze_video_url(body: AnalyzeRequest):
    raw = body.url.strip()
    if not raw:
        raise HTTPException(status_code=400, detail="请输入视频链接")

    pure_url = extract_url(raw)
    platform = detect_platform(pure_url)
    logger.info("Web skill analyze: platform=%s url=%s", platform, pure_url[:80])

    try:
        video_url = resolve_short_url(pure_url)
        session_id = uuid.uuid4().hex[:12]
        video_path = await asyncio.to_thread(download_video, video_url, session_id)
        result = await asyncio.to_thread(ai_analyze, video_path)
    except Exception as e:
        logger.error("Web skill analyze failed: %s", e)
        raise HTTPException(status_code=500, detail=f"视频分析失败：{e}")
    finally:
        if 'session_id' in dir():
            import shutil as _shutil
            _cleanup(session_id)

    title = result["title"]
    steps_data = result["steps"]

    steps = [
        {
            "instruction": s.get("instruction", ""),
            "target_text": s.get("target_text", ""),
            "target_type": s.get("target_type", "text"),
            "target_description": s.get("target_description", ""),
            "page_description": s.get("page_description", ""),
        }
        for s in steps_data
    ]

    logger.info("Web skill analyze done: title='%s' steps=%d", title, len(steps))
    return {"title": title, "steps": steps, "platform": platform,
            "app_name": result.get("app_name", ""), "app_package": result.get("app_package", "")}


@router.post("/analyze/upload")
async def analyze_video_upload(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="请选择视频文件")

    ext = os.path.splitext(file.filename)[1] or ".mp4"
    session_id = uuid.uuid4().hex[:12]
    tmp_path = os.path.join(tempfile.gettempdir(), f"upload_{session_id}{ext}")

    try:
        with open(tmp_path, "wb") as f:
            content = await file.read()
            f.write(content)
        logger.info("Web skill upload: %s (%.1fMB)", file.filename, len(content) / 1024 / 1024)

        result = await asyncio.to_thread(ai_analyze, tmp_path)
    except Exception as e:
        logger.error("Web skill upload analyze failed: %s", e)
        raise HTTPException(status_code=500, detail=f"视频分析失败：{e}")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    title = result["title"]
    steps_data = result["steps"]

    steps = [
        {
            "instruction": s.get("instruction", ""),
            "target_text": s.get("target_text", ""),
            "target_type": s.get("target_type", "text"),
            "target_description": s.get("target_description", ""),
            "page_description": s.get("page_description", ""),
        }
        for s in steps_data
    ]

    logger.info("Web skill upload analyze done: title='%s' steps=%d", title, len(steps))
    return {"title": title, "steps": steps, "platform": "upload",
            "app_name": result.get("app_name", ""), "app_package": result.get("app_package", "")}


def _cleanup(session_id: str):
    download_dir = os.path.join(tempfile.gettempdir(), "tutorial_downloads", session_id)
    if os.path.exists(download_dir):
        shutil.rmtree(download_dir, ignore_errors=True)
