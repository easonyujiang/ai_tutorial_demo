from pydantic import BaseModel

class RectModel(BaseModel):
    left: float
    top: float
    width: float
    height: float

class StepModel(BaseModel):
    image: str = ""
    instruction: str
    rect: RectModel
    bubble_dir: str = "top"  # top, bottom, left, right

class TutorialResponse(BaseModel):
    id: str
    title: str
    steps: list[StepModel]