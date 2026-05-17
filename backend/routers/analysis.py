import os
import uuid
import shutil

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel
import yt_dlp

from models.tutorial import TutorialResponse, StepModel, RectModel
from services.ai_service import analyze_video as run_ai_analysis

router = APIRouter()

class AnalyzeRequest(BaseModel):
    url: str

def get_video_info(url: str) -> dict:
    ydl_opts = {
        "skip_download": True,
        "quiet": True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"无法获取视频信息：{e}")

    title = info.get("title") if isinstance(info, dict) else None
    if not title:
        raise HTTPException(status_code=400, detail="无法获取视频标题")

    return {"title": title}

@router.post("/api/analyze", response_model=TutorialResponse)
async def analyze_video(request: AnalyzeRequest):
    video_info = get_video_info(request.url)
    title = video_info["title"]

    return TutorialResponse(
        id="custom_guide",
        title=title,
        steps=[
            StepModel(
                image="",
                instruction=f"欢迎观看「{title}」，请点击这里开始第一步",
                rect=RectModel(left=0.05, top=0.22, width=0.9, height=0.08),
                bubble_dir="bottom",
            ),
            StepModel(
                image="",
                instruction=f"根据「{title}」的演示内容，请关注这个关键操作区域",
                rect=RectModel(left=0.68, top=0.38, width=0.25, height=0.1),
                bubble_dir="left",
            ),
            StepModel(
                image="",
                instruction=f"完成「{title}」中的最后一步后，请点击这里结束教程",
                rect=RectModel(left=0.08, top=0.66, width=0.84, height=0.08),
                bubble_dir="top",
            ),
        ],
    )

TEMP_DIR = "temp_uploads"
MAX_UPLOAD_SIZE = 100 * 1024 * 1024
DEMO_VIDEO_PATH = os.path.join("demo_videos", "Test.mov")

os.makedirs(TEMP_DIR, exist_ok=True)


@router.post("/api/analyze-local", response_model=TutorialResponse)
async def analyze_local_video(video: UploadFile = File(...)):
    if not video.filename:
        raise HTTPException(status_code=400, detail="未选择文件")

    file_ext = os.path.splitext(video.filename)[1] or ".mp4"
    unique_name = f"{uuid.uuid4().hex}{file_ext}"
    temp_path = os.path.join(TEMP_DIR, unique_name)

    try:
        content = await video.read()
        if len(content) > MAX_UPLOAD_SIZE:
            raise HTTPException(status_code=413, detail="文件大小超过 100MB 限制")

        with open(temp_path, "wb") as f:
            f.write(content)

        result = run_ai_analysis(temp_path)
        return result

    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"处理失败：{e}")
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


@router.post("/api/analyze-demo", response_model=TutorialResponse)
async def analyze_demo_video():
    if not os.path.exists(DEMO_VIDEO_PATH):
        raise HTTPException(
            status_code=404,
            detail=f"演示视频未找到，请将 Test.mov 放到 backend/demo_videos/ 目录下",
        )

    try:
        result = run_ai_analysis(DEMO_VIDEO_PATH)
        return result
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"分析失败：{e}")