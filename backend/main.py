import time
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from infrastructure.logger import setup_logging, get_logger
from infrastructure.session_manager import SessionManager
from routers import tutorial_router

load_dotenv()

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    logger.info("=" * 50)
    logger.info("AI Tutorial Backend v2.0.0 starting...")
    app.state.session_manager = SessionManager()
    app.state.ocr_service = None
    logger.info("SessionManager initialized")
    yield
    logger.info("AI Tutorial Backend shutting down")


app = FastAPI(
    title="AI Tutorial Backend",
    version="2.0.0",
    lifespan=lifespan,
)

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
    logger.info(
        "%s %s → %s (%.1fms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response


app.include_router(tutorial_router.router)


@app.get("/")
async def root():
    return {
        "service": "AI Tutorial Backend",
        "version": "2.0.0",
        "status": "running",
    }
