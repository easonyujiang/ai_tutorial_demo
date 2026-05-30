import time
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.datastructures import UploadFile
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from infrastructure.logger import setup_logging, get_logger
from infrastructure.log_capture import get_log_capture
from infrastructure.session_manager import SessionManager
from config import settings
from routers import tutorial_router, chat_router, legacy_router, monitor_router, skill_router, video_router

load_dotenv()

logger = get_logger(__name__)
VIDEO_STORE_DIR = Path(__file__).resolve().parent / "demo_videos"

limiter = Limiter(key_func=get_remote_address, default_limits=[settings.rate_limit])


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    get_log_capture()
    VIDEO_STORE_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("=" * 50)
    logger.info("AI Tutorial Backend v2.0.0 starting...")
    app.state.session_manager = SessionManager()
    app.state.ocr_service = None
    logger.info("SessionManager initialized")
    logger.info("Monitor available at http://localhost:8000/monitor")
    yield
    logger.info("AI Tutorial Backend shutting down")


app = FastAPI(
    title="AI Tutorial Backend",
    version="2.0.0",
    lifespan=lifespan,
    max_request_body_size=500 * 1024 * 1024,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = (time.perf_counter() - start) * 1000
    if duration_ms > 500 or response.status_code >= 400:
        logger.info(
            "%s %s → %s (%.1fms)",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
    return response


app.include_router(tutorial_router.router)
app.include_router(chat_router.router)
app.include_router(legacy_router.router)
app.include_router(monitor_router.router)
app.include_router(skill_router.router)
app.include_router(video_router.router)
app.mount("/videos", StaticFiles(directory=str(VIDEO_STORE_DIR)), name="videos")

@app.get("/")
async def root():
    return {
        "service": "AI Tutorial Backend",
        "version": "2.0.0",
        "status": "running",
    }
