import json
import os
import tempfile
import time
import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel

from models.skill import Skill, get_skill_store
from infrastructure.logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/api/skills", tags=["skills"])

_DEMO_RESULTS_PATH = Path(__file__).resolve().parents[1] / "data" / "demo_results.json"


def _load_demos() -> list[dict]:
    if not _DEMO_RESULTS_PATH.exists():
        return []
    with open(_DEMO_RESULTS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def _pick_demo(url: str) -> dict | None:
    demos = _load_demos()
    if not demos:
        return None
    return demos[abs(hash(url)) % len(demos)]


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
    url = body.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="请输入视频链接")

    logger.info("Web skill analyze: url=%s", url[:80])
    time.sleep(1.8)

    demo = _pick_demo(url)
    if demo:
        title = str(demo.get("title", "教程"))
        steps_data = demo.get("steps", [])
        app_name = str(demo.get("app_name", ""))
        app_package = str(demo.get("app_package", ""))
    else:
        title = "演示教程"
        steps_data = [
            {"instruction": "打开目标应用", "target_text": "", "target_type": "icon", "target_description": "应用图标", "page_description": "手机主屏幕"},
            {"instruction": "按照提示点击对应按钮", "target_text": "设置", "target_type": "text", "target_description": "设置选项", "page_description": "应用内页面"},
            {"instruction": "完成操作后返回", "target_text": "", "target_type": "icon", "target_description": "返回按钮", "page_description": "任意页面"},
        ]
        app_name = ""
        app_package = ""

    steps = [
        {
            "instruction": str(s.get("instruction", "")),
            "target_text": str(s.get("target_text", "")),
            "target_type": str(s.get("target_type", "text")),
            "target_description": str(s.get("target_description", "")),
            "page_description": str(s.get("page_description", "")),
        }
        for s in steps_data
    ]

    logger.info("Web skill analyze done: title='%s' steps=%d", title, len(steps))
    return {"title": title, "steps": steps, "platform": "demo",
            "app_name": app_name, "app_package": app_package}


@router.post("/analyze/upload")
async def analyze_video_upload(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="请选择视频文件")

    ext = os.path.splitext(file.filename)[1] or ".mp4"
    session_id = uuid.uuid4().hex[:12]
    tmp_path = os.path.join(tempfile.gettempdir(), f"upload_{session_id}{ext}")

    try:
        total = 0
        with open(tmp_path, "wb") as f:
            while chunk := await file.read(2 * 1024 * 1024):
                f.write(chunk)
                total += len(chunk)
        logger.info("Web skill upload: %s (%.1fMB)", file.filename, total / 1024 / 1024)

        time.sleep(1.5)
        demo = _pick_demo(str(uuid.uuid4()))
        if demo:
            title = str(demo.get("title", "教程"))
            steps_data = demo.get("steps", [])
            app_name = str(demo.get("app_name", ""))
            app_package = str(demo.get("app_package", ""))
        else:
            title = "演示教程"
            steps_data = [
                {"instruction": "打开目标应用", "target_text": "", "target_type": "icon", "target_description": "应用图标", "page_description": "手机主屏幕"},
                {"instruction": "按照提示点击对应按钮", "target_text": "设置", "target_type": "text", "target_description": "设置选项", "page_description": "应用内页面"},
                {"instruction": "完成操作后返回", "target_text": "", "target_type": "icon", "target_description": "返回按钮", "page_description": "任意页面"},
            ]
            app_name = ""
            app_package = ""

        steps = [
            {
                "instruction": str(s.get("instruction", "")),
                "target_text": str(s.get("target_text", "")),
                "target_type": str(s.get("target_type", "text")),
                "target_description": str(s.get("target_description", "")),
                "page_description": str(s.get("page_description", "")),
            }
            for s in steps_data
        ]
        logger.info("Web skill upload analyze done: title='%s' steps=%d", title, len(steps))
        return {"title": title, "steps": steps, "platform": "demo",
                "app_name": app_name, "app_package": app_package}
    except Exception as e:
        logger.warning("Web skill upload analyze fallback: %s", e)
        raise HTTPException(status_code=500, detail=f"视频分析失败：{e}")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
