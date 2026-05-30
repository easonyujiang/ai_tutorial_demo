import asyncio
import json
import os
import shutil
import time
import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from infrastructure.logger import get_logger
from services.ai_service import analyze_video, _demo_analysis, _is_placeholder_api_key
from config import settings

logger = get_logger(__name__)

router = APIRouter(prefix="/api/videos", tags=["videos"])

PROJECT_ROOT = Path(__file__).resolve().parents[2]
VIDEO_STORE_DIR = PROJECT_ROOT / "backend" / "demo_videos"
DEMO_RESULTS_FILE = PROJECT_ROOT / "backend" / "data" / "demo_results.json"
ALLOWED_EXTENSIONS = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}


class ImportLocalVideosRequest(BaseModel):
    path: str


def ensure_video_store_dir() -> None:
    VIDEO_STORE_DIR.mkdir(parents=True, exist_ok=True)


def _iter_video_files(path: Path) -> list[Path]:
    if path.is_file():
        return [path] if path.suffix.lower() in ALLOWED_EXTENSIONS else []

    if not path.is_dir():
        return []

    files = [
        p for p in sorted(path.iterdir())
        if p.is_file() and p.suffix.lower() in ALLOWED_EXTENSIONS
    ]
    return files


def _copy_to_store(src: Path) -> str:
    ensure_video_store_dir()
    target_name = f"{uuid.uuid4().hex}{src.suffix.lower()}"
    target_path = VIDEO_STORE_DIR / target_name
    shutil.copy2(src, target_path)
    return target_name


def _build_url(request: Request, filename: str) -> str:
    return str(request.base_url).rstrip("/") + f"/videos/{filename}"


@router.post("/import-local")
async def import_local_videos(request: Request, body: ImportLocalVideosRequest):
    raw_path = body.path.strip()
    if not raw_path:
        raise HTTPException(status_code=400, detail="请输入本地视频路径")

    source = Path(raw_path).expanduser()
    if not source.exists():
        raise HTTPException(status_code=404, detail="本地路径不存在")

    video_files = _iter_video_files(source)
    if not video_files:
        raise HTTPException(status_code=400, detail="该路径下没有可导入的视频文件")

    imported = []
    for src in video_files:
        filename = _copy_to_store(src)
        size_bytes = os.path.getsize(VIDEO_STORE_DIR / filename)
        imported.append({
            "source_path": str(src),
            "filename": filename,
            "size_bytes": size_bytes,
            "url": _build_url(request, filename),
        })

    logger.info("Imported %d local videos from %s", len(imported), raw_path)
    return {
        "ok": True,
        "count": len(imported),
        "items": imported,
    }


# ── Pre-computed Demo API ──────────────────────────────────────────


def _load_demo_results() -> list[dict]:
    if not DEMO_RESULTS_FILE.exists():
        return []
    with open(DEMO_RESULTS_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def _save_demo_results(results: list[dict]) -> None:
    DEMO_RESULTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(DEMO_RESULTS_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)


def _analyze_single_video(video_path: str) -> dict | None:
    """Run AI analysis on one video file. Returns None if skipped."""
    api_key = settings.openai_api_key or os.getenv("OPENAI_API_KEY", "")
    if _is_placeholder_api_key(api_key):
        logger.warning("API Key is placeholder, using demo analysis for %s", os.path.basename(video_path))
        return _demo_analysis("API Key 未配置")

    try:
        result = analyze_video(video_path)
        return result
    except Exception as e:
        logger.error("Analysis failed for %s: %s", os.path.basename(video_path), e)
        return None


@router.post("/pre-analyze-all")
async def pre_analyze_all_videos(request: Request):
    ensure_video_store_dir()

    video_files = sorted(
        [p for p in VIDEO_STORE_DIR.iterdir() if p.suffix.lower() in ALLOWED_EXTENSIONS]
    )
    if not video_files:
        raise HTTPException(status_code=400, detail="demo_videos 目录下没有视频文件")

    logger.info("=" * 50)
    logger.info("PRE-ANALYZE: starting batch analysis of %d videos", len(video_files))

    results = []
    for idx, video_file in enumerate(video_files, 1):
        filename = video_file.name
        logger.info("[%d/%d] Analyzing: %s", idx, len(video_files), filename)

        analysis = await asyncio.to_thread(_analyze_single_video, str(video_file))
        if analysis is None:
            logger.warning("[%d/%d] SKIPPED (analysis returned None): %s", idx, len(video_files), filename)
            continue

        title = str(analysis.get("title", "未命名"))
        steps = []
        for s in analysis.get("steps", []):
            steps.append({
                "instruction": str(s.get("instruction", "")),
                "target_text": str(s.get("target_text", "")),
                "target_type": str(s.get("target_type", "text")),
                "target_description": str(s.get("target_description", "")),
                "page_description": str(s.get("page_description", "")),
            })

        video_url = _build_url(request, filename)
        demo_entry = {
            "id": filename.rsplit(".", 1)[0],
            "title": title,
            "video_filename": filename,
            "video_url": video_url,
            "steps": steps,
            "app_name": str(analysis.get("app_name", "")),
            "app_package": str(analysis.get("app_package", "")),
            "pre_analyzed_at": time.time(),
        }
        results.append(demo_entry)
        logger.info("[%d/%d] DONE: title='%s' steps=%d", idx, len(video_files), title, len(steps))

    _save_demo_results(results)

    logger.info("PRE-ANALYZE: complete, saved %d demos to %s", len(results), DEMO_RESULTS_FILE)
    return {"ok": True, "count": len(results), "demos": results}


@router.get("/demos")
async def list_demos():
    demos = _load_demo_results()
    return {"demos": demos}


@router.get("/demos/{demo_id}")
async def get_demo(demo_id: str):
    demos = _load_demo_results()
    for demo in demos:
        if demo.get("id") == demo_id:
            return demo
    raise HTTPException(status_code=404, detail="演示数据不存在")
