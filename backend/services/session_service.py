from infrastructure.logger import get_logger
from models.tutorial import (
    TutorialSession,
    TutorialStep,
    SessionStatus,
    ExecuteResponse,
    ScreenshotRequest,
    StepActionResponse,
)
from models.ocr import OCRResult
from services.ocr_service import recognize

logger = get_logger(__name__)


def get_current_step(session: TutorialSession) -> ExecuteResponse:
    logger.info(
        "get_current_step: session=%s, status=%s, step=%d/%d",
        session.session_id, session.status.value,
        session.current_step_index, len(session.steps),
    )

    if session.status == SessionStatus.COMPLETED:
        logger.info("Tutorial already completed")
        return ExecuteResponse(completed=True)

    if session.current_step_index >= len(session.steps):
        session.status = SessionStatus.COMPLETED
        logger.info("All steps done, marking completed")
        return ExecuteResponse(completed=True)

    step = session.steps[session.current_step_index]
    step.status = "active"
    session.status = SessionStatus.IN_PROGRESS

    logger.info(
        "Step %d/%d: target='%s', page='%s'",
        step.index + 1, len(session.steps),
        step.target_text, step.page_description,
    )

    return ExecuteResponse(
        completed=False,
        step_index=step.index,
        total_steps=len(session.steps),
        instruction=step.instruction,
        target_text=step.target_text,
        page_description=step.page_description,
    )


def handle_screenshot(
    session: TutorialSession, request: ScreenshotRequest
) -> OCRResult:
    step_index = request.step_index
    logger.info(
        "handle_screenshot: session=%s, step=%d/%d",
        session.session_id, step_index, len(session.steps),
    )

    if step_index < 0 or step_index >= len(session.steps):
        raise ValueError(f"步骤索引 {step_index} 超出范围")

    step = session.steps[step_index]
    result = recognize(request.image_base64, step.target_text, step_index)
    return result


def handle_confirm(
    session: TutorialSession, step_index: int
) -> StepActionResponse:
    logger.info(
        "handle_confirm: session=%s, step=%d/%d",
        session.session_id, step_index, len(session.steps),
    )

    if step_index < 0 or step_index >= len(session.steps):
        raise ValueError(f"步骤索引 {step_index} 超出范围")

    step = session.steps[step_index]
    step.status = "completed"

    next_index = step_index + 1
    session.current_step_index = next_index

    if next_index >= len(session.steps):
        session.status = SessionStatus.COMPLETED
        logger.info("All steps completed! Tutorial finished")
    else:
        logger.info("Advanced to step %d/%d", next_index, len(session.steps))

    return StepActionResponse(ok=True, next_step=next_index)


def handle_skip(
    session: TutorialSession, step_index: int
) -> StepActionResponse:
    logger.info(
        "handle_skip: session=%s, step=%d/%d",
        session.session_id, step_index, len(session.steps),
    )

    if step_index < 0 or step_index >= len(session.steps):
        raise ValueError(f"步骤索引 {step_index} 超出范围")

    step = session.steps[step_index]
    step.status = "skipped"

    next_index = step_index + 1
    session.current_step_index = next_index

    if next_index >= len(session.steps):
        session.status = SessionStatus.COMPLETED
        logger.info("All steps done after skip")
    else:
        logger.info("Skipped step %d, now at %d/%d",
                    step_index, next_index, len(session.steps))

    return StepActionResponse(ok=True, next_step=next_index)
