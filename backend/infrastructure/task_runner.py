import asyncio
import time
import shutil
import os

from models.tutorial import TutorialSession, TutorialStep, SessionStatus
from config import settings
from services.video_service import (
    detect_platform,
    extract_url,
    resolve_short_url,
    download_video,
)
from services.ai_service import analyze_video
from infrastructure.logger import get_logger

logger = get_logger(__name__)


def _update_progress(session, manager, msg, status=None):
    session.progress = msg
    if status:
        session.status = status
    manager.update(session.session_id, session)


async def run_analysis(session: TutorialSession, session_manager):
    session_id = session.session_id
    logger.info("=" * 40)
    logger.info("Analysis task started: session=%s, url=%s",
                session_id, session.video_url[:80])

    t_start = time.perf_counter()

    try:
        api_key = settings.openai_api_key or os.getenv("OPENAI_API_KEY", "")
        is_placeholder = not api_key or "your-api-key" in api_key.lower() or api_key == "sk-your-api-key-here"
        if is_placeholder:
            _update_progress(session, session_manager, "演示模式：跳过视频下载与分析", SessionStatus.READY)
            session.title = "演示教程（API Key 未配置）"
            session.platform = "demo"
            session.steps = [
                TutorialStep(index=0, instruction="打开目标应用或回到需要操作的页面", target_text="", target_type="icon", target_description="无（演示步骤）", page_description="任意页面"),
                TutorialStep(index=1, instruction="按照教程提示找到对应按钮并点击", target_text="", target_type="icon", target_description="无（演示步骤）", page_description="任意页面"),
                TutorialStep(index=2, instruction="完成操作后返回本应用继续下一步", target_text="", target_type="icon", target_description="无（演示步骤）", page_description="任意页面"),
            ]
            elapsed = time.perf_counter() - t_start
            logger.info("Analysis task SKIPPED (demo mode): session=%s (%.1fs)", session_id, elapsed)
            return

        raw_input = session.video_url
        pure_url = extract_url(raw_input)
        platform = detect_platform(pure_url)
        logger.info("Platform detected: %s", platform)

        if platform == "bilibili":
            _update_progress(session, session_manager, "B站风控拦截，使用预分析演示模式", SessionStatus.READY)
            session.title = "演示教程（B站风控，请用本地视频或预分析演示）"
            session.platform = "bilibili"
            session.steps = [
                TutorialStep(index=0, instruction="打开目标应用或回到需要操作的页面", target_text="", target_type="icon", target_description="无（演示步骤）", page_description="任意页面"),
                TutorialStep(index=1, instruction="按照教程提示找到对应按钮并点击", target_text="", target_type="icon", target_description="无（演示步骤）", page_description="任意页面"),
                TutorialStep(index=2, instruction="完成操作后返回本应用继续下一步", target_text="", target_type="icon", target_description="无（演示步骤）", page_description="任意页面"),
            ]
            elapsed = time.perf_counter() - t_start
            logger.info("B站分析跳过（风控）: session=%s (%.1fs)", session_id, elapsed)
            return

        video_url = resolve_short_url(pure_url)

        _update_progress(session, session_manager, "正在下载视频...")
        logger.info("Starting video download...")
        video_path = await asyncio.to_thread(download_video, video_url, session.session_id)
        logger.info("Video download complete: %s", video_path)

        _update_progress(session, session_manager, "正在压缩视频...")
        logger.info("Starting AI video analysis...")
        result = await asyncio.to_thread(analyze_video, video_path)
        title = result["title"]
        steps_data = result["steps"]

        _update_progress(session, session_manager, "分析完成", SessionStatus.READY)
        session.title = title
        session.platform = platform
        session.steps = [
            TutorialStep(
                index=i,
                instruction=s["instruction"],
                target_text=s["target_text"],
                target_description=s.get("target_description", ""),
                target_type=s.get("target_type", "text"),
                page_description=s["page_description"],
            )
            for i, s in enumerate(steps_data)
        ]

        elapsed = time.perf_counter() - t_start
        logger.info(
            "Analysis task SUCCESS: session=%s, title='%s', steps=%d (%.1fs)",
            session_id, title, len(steps_data), elapsed,
        )

    except Exception as e:
        session.progress = f"失败: {e}"
        session.status = SessionStatus.ERROR
        session.error_message = str(e)
        elapsed = time.perf_counter() - t_start
        logger.error(
            "Analysis task FAILED: session=%s, error=%s (%.1fs)",
            session_id, e, elapsed,
        )

    finally:
        _cleanup_temp_files(session.session_id)
        session_manager.update(session.session_id, session)
        logger.info("Analysis task ended: session=%s", session_id)


def _cleanup_temp_files(session_id: str):
    import os
    import tempfile

    download_dir = os.path.join(
        tempfile.gettempdir(), "tutorial_downloads", session_id
    )
    if os.path.exists(download_dir):
        shutil.rmtree(download_dir, ignore_errors=True)
        logger.debug("Cleaned up temp files: %s", download_dir)
