import asyncio
import time
import shutil

from models.tutorial import TutorialSession, TutorialStep, SessionStatus
from services.video_service import (
    detect_platform,
    extract_url,
    resolve_short_url,
    download_video,
)
from services.ai_service import analyze_video
from infrastructure.logger import get_logger

logger = get_logger(__name__)


async def run_analysis(session: TutorialSession, session_manager):
    session_id = session.session_id
    logger.info("=" * 40)
    logger.info("Analysis task started: session=%s, url=%s",
                session_id, session.video_url[:80])

    t_start = time.perf_counter()

    try:
        raw_input = session.video_url
        pure_url = extract_url(raw_input)
        platform = detect_platform(pure_url)
        logger.info("Platform detected: %s", platform)

        video_url = resolve_short_url(pure_url)

        logger.info("Starting video download...")
        video_path = await asyncio.to_thread(download_video, video_url, session.session_id)
        logger.info("Video download complete: %s", video_path)

        logger.info("Starting AI video analysis...")
        result = await asyncio.to_thread(analyze_video, video_path)
        title = result["title"]
        steps_data = result["steps"]

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
        session.status = SessionStatus.READY

        elapsed = time.perf_counter() - t_start
        logger.info(
            "Analysis task SUCCESS: session=%s, title='%s', steps=%d (%.1fs)",
            session_id, title, len(steps_data), elapsed,
        )

    except Exception as e:
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
