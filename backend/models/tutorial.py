from pydantic import BaseModel, Field
from enum import Enum
from datetime import datetime


class RectModel(BaseModel):
    left: float
    top: float
    width: float
    height: float


class TutorialStep(BaseModel):
    index: int
    instruction: str
    target_text: str
    target_description: str = ""
    target_type: str = "text"
    page_description: str = ""
    status: str = "pending"
    completed_at: datetime | None = None


class SessionStatus(str, Enum):
    PROCESSING = "processing"
    READY = "ready"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    ERROR = "error"


class TutorialSession(BaseModel):
    session_id: str = ""
    title: str = ""
    platform: str = ""
    video_url: str = ""
    steps: list[TutorialStep] = []
    current_step_index: int = 0
    status: SessionStatus = SessionStatus.PROCESSING
    created_at: datetime = Field(default_factory=datetime.now)
    error_message: str = ""
    progress: str = ""


class CreateTutorialRequest(BaseModel):
    url: str


class CreateTutorialResponse(BaseModel):
    session_id: str
    status: str
    message: str


class SessionStatusResponse(BaseModel):
    session_id: str
    status: str
    title: str
    total_steps: int
    current_step: int
    steps: list[TutorialStep]
    progress: str = ""


class StepsResponse(BaseModel):
    session_id: str
    title: str
    steps: list[TutorialStep]


class ExecuteResponse(BaseModel):
    completed: bool
    step_index: int = -1
    total_steps: int = 0
    instruction: str = ""
    target_text: str = ""
    page_description: str = ""


class ScreenshotRequest(BaseModel):
    step_index: int
    image_base64: str
    screen_width: int = 0
    screen_height: int = 0


class StepActionRequest(BaseModel):
    step_index: int
    reason: str = ""


class StepActionResponse(BaseModel):
    ok: bool
    next_step: int = -1
