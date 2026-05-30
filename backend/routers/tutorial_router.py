import asyncio

from fastapi import APIRouter, HTTPException, Request

from infrastructure.logger import get_logger
from infrastructure.task_runner import run_analysis
from models.tutorial import (
    TutorialSession,
    CreateTutorialRequest,
    CreateTutorialResponse,
    SessionStatusResponse,
    StepsResponse,
    ExecuteResponse,
    ScreenshotRequest,
    StepActionRequest,
    StepActionResponse,
    SessionStatus,
)
from services import session_service

logger = get_logger(__name__)

router = APIRouter(prefix="/api/v1/tutorial", tags=["tutorial"])


def _get_manager(request: Request):
    return request.app.state.session_manager


@router.post("/create", response_model=CreateTutorialResponse, status_code=202)
async def create_tutorial(request: Request, body: CreateTutorialRequest):
    url = body.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="请输入视频链接")

    session = TutorialSession(video_url=url)
    session_id = _get_manager(request).create(session)

    asyncio.create_task(run_analysis(session, _get_manager(request)))

    return CreateTutorialResponse(
        session_id=session_id,
        status=SessionStatus.PROCESSING.value,
        message="视频下载中，请稍候...",
    )


@router.get("/{session_id}/status", response_model=SessionStatusResponse)
async def get_status(request: Request, session_id: str):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")

    return SessionStatusResponse(
        session_id=session.session_id,
        status=session.status.value,
        title=session.title,
        total_steps=len(session.steps),
        current_step=session.current_step_index,
        steps=session.steps,
        progress=session.progress,
    )


@router.get("/{session_id}/steps", response_model=StepsResponse)
async def get_steps(request: Request, session_id: str):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")

    return StepsResponse(
        session_id=session.session_id,
        title=session.title,
        steps=session.steps,
    )


@router.post("/{session_id}/execute", response_model=ExecuteResponse)
async def execute_step(request: Request, session_id: str):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")

    try:
        result = session_service.get_current_step(session)
        _get_manager(request).update(session_id, session)
        return result
    except Exception as e:
        logger.error("execute_step error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{session_id}/screenshot")
async def upload_screenshot(request: Request, session_id: str, body: ScreenshotRequest):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")

    try:
        result = session_service.handle_screenshot(session, body)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("upload_screenshot error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{session_id}/confirm", response_model=StepActionResponse)
async def confirm_step(request: Request, session_id: str, body: StepActionRequest):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")

    try:
        result = session_service.handle_confirm(session, body.step_index)
        _get_manager(request).update(session_id, session)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("confirm_step error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{session_id}/skip", response_model=StepActionResponse)
async def skip_step(request: Request, session_id: str, body: StepActionRequest):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")

    try:
        result = session_service.handle_skip(session, body.step_index)
        _get_manager(request).update(session_id, session)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("skip_step error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{session_id}")
async def cancel_tutorial(request: Request, session_id: str):
    session = _get_manager(request).get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在")
    _get_manager(request).delete(session_id)
    return {"ok": True}
