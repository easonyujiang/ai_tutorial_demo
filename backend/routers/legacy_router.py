import json
import time
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from infrastructure.logger import get_logger

logger = get_logger(__name__)
router = APIRouter()

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


@router.post("/api/info")
async def get_video_info(body: AnalyzeRequest):
    url = body.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="请输入视频链接")
    return {"title": url[:80], "platform": "demo"}


@router.post("/api/analyze")
async def analyze_video(body: AnalyzeRequest):
    url = body.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="请输入视频链接")

    time.sleep(1.5)

    demo = _pick_demo(url)
    if demo:
        title = str(demo.get("title", "教程"))
        raw_steps = demo.get("steps", [])
    else:
        title = "演示教程"
        raw_steps = [
            {"instruction": "打开目标应用", "target_text": "", "target_type": "icon", "target_description": "应用图标", "page_description": "手机主屏幕"},
            {"instruction": "按照提示点击对应按钮", "target_text": "设置", "target_type": "text", "target_description": "设置选项", "page_description": "应用内页面"},
            {"instruction": "完成操作后返回", "target_text": "", "target_type": "icon", "target_description": "返回按钮", "page_description": "任意页面"},
        ]

    steps = [
        {
            "image": "",
            "instruction": str(s.get("instruction", "")),
            "target_text": str(s.get("target_text", "")),
            "target_type": str(s.get("target_type", "text")),
            "target_description": str(s.get("target_description", "")),
            "page_description": str(s.get("page_description", "")),
            "rect": {"left": 0.05 + (i * 0.05), "top": 0.22 + (i * 0.15), "width": 0.9, "height": 0.08},
            "bubble_dir": "bottom" if i % 2 == 0 else "left",
        }
        for i, s in enumerate(raw_steps)
    ]

    logger.info("Legacy analyze done: title='%s' steps=%d", title, len(steps))
    return {"id": "demo_session", "title": title, "steps": steps}


@router.post("/api/tutorial-template")
async def tutorial_template(request: dict):
    title = request.get("title", "").strip()
    if not title:
        raise HTTPException(status_code=400, detail="请输入教程标题")
    return {"id": "template_guide", "title": title, "steps": []}
