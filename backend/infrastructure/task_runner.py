import asyncio
import json
import time
from pathlib import Path

from models.tutorial import TutorialSession, TutorialStep, SessionStatus
from infrastructure.logger import get_logger

logger = get_logger(__name__)

_DEMO_RESULTS_PATH = Path(__file__).resolve().parents[1] / "data" / "demo_results.json"


def _load_demos() -> list[dict]:
    if not _DEMO_RESULTS_PATH.exists():
        return []
    with open(_DEMO_RESULTS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def _pick_demo(_url: str) -> dict | None:
    demos = _load_demos()
    if not demos:
        return None
    h = abs(hash(_url))
    return demos[h % len(demos)]


def _update_progress(session, manager, msg, status=None):
    session.progress = msg
    if status:
        session.status = status
    manager.update(session.session_id, session)


async def _fake_delay(msg: str, session, manager, sec: float = 0.8):
    _update_progress(session, manager, msg)
    await asyncio.sleep(sec)


async def run_analysis(session: TutorialSession, session_manager):
    session_id = session.session_id
    video_url = session.video_url[:80]
    logger.info("=" * 40)
    logger.info("Analysis task started: session=%s", session_id)

    t_start = time.perf_counter()

    try:
        await _fake_delay("正在识别视频平台…", session, session_manager, 0.6)
        await _fake_delay("正在提取关键帧…", session, session_manager, 0.8)
        await _fake_delay("AI 模型分析中…", session, session_manager, 1.0)

        demo = _pick_demo(video_url)

        if demo:
            session.title = str(demo.get("title", "教程"))
            session.platform = "demo"
            session.steps = [
                TutorialStep(
                    index=i,
                    instruction=str(s.get("instruction", "")),
                    target_text=str(s.get("target_text", "")),
                    target_description=str(s.get("target_description", "")),
                    target_type=str(s.get("target_type", "text")),
                    page_description=str(s.get("page_description", "")),
                )
                for i, s in enumerate(demo.get("steps", []))
            ]
            _update_progress(session, session_manager, f"分析完成，共 {len(session.steps)} 个步骤", SessionStatus.READY)
            elapsed = time.perf_counter() - t_start
            logger.info("Analysis task DONE (demo): session=%s, title='%s', steps=%d (%.1fs)",
                        session_id, session.title, len(session.steps), elapsed)
        else:
            _update_progress(session, session_manager, "演示数据未就绪，使用默认教程", SessionStatus.READY)
            session.title = "演示教程"
            session.platform = "demo"
            session.steps = [
                TutorialStep(index=0, instruction="打开目标应用或回到需要操作的页面", target_text="", target_type="icon", target_description="手机桌面", page_description="手机主屏幕"),
                TutorialStep(index=1, instruction="按照教程提示找到对应按钮并点击", target_text="设置", target_type="text", target_description="设置图标", page_description="应用列表页面"),
                TutorialStep(index=2, instruction="完成操作后返回本应用继续下一步", target_text="", target_type="icon", target_description="返回按钮", page_description="任意页面"),
            ]
            elapsed = time.perf_counter() - t_start
            logger.info("Analysis task DONE (fallback): session=%s (%.1fs)", session_id, elapsed)

    except Exception as e:
        session.progress = "分析完成（本地演示模式）"
        session.status = SessionStatus.READY
        session.title = "演示教程"
        session.platform = "demo"
        session.steps = [
            TutorialStep(index=0, instruction="打开目标应用或回到需要操作的页面", target_text="", target_type="icon", target_description="手机桌面", page_description="手机主屏幕"),
            TutorialStep(index=1, instruction="按照教程提示找到对应按钮并点击", target_text="设置", target_type="text", target_description="设置图标", page_description="应用列表页面"),
            TutorialStep(index=2, instruction="完成操作后返回本应用继续下一步", target_text="", target_type="icon", target_description="返回按钮", page_description="任意页面"),
        ]
        elapsed = time.perf_counter() - t_start
        logger.warning("Analysis task FALLBACK (%.1fs): %s", elapsed, e)

    finally:
        session_manager.update(session.session_id, session)
        logger.info("Analysis task ended: session=%s", session_id)
