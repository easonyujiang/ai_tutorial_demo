from pydantic import BaseModel

from models.tutorial import RectModel


class OCRTextBox(BaseModel):
    text: str
    confidence: float
    rect: RectModel


class OCRResult(BaseModel):
    step_index: int
    found: bool
    target_text: str
    bboxes: list[OCRTextBox] = []
    all_texts: list[OCRTextBox] = []
    suggestion: str = ""
