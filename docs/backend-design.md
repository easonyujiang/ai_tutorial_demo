# AI Tutorial Backend 重构开发文档（DEMO 精简版）

## 一、项目概述

### 1.1 核心目标

将现有的一体式"视频→AI分析→返回全部步骤"模式，重构为**交互式逐步引导**模式。DEMO 阶段采用纯 REST 通信，保持极简。

### 1.2 核心流程

```
用户粘贴视频链接
       ↓
POST /create  →  后端下载视频 + AI 分析  →  生成步骤
       ↓
GET /status   →  前端轮询等待分析完成
       ↓
POST /execute  →  后端返回当前步骤的引导指令（target_text + page_description）
       ↓
前端引导用户跳转页面 → 截图
       ↓
POST /screenshot  →  后端 OCR 识别 → 返回目标区域高亮坐标
       ↓
用户点击高亮区域 → POST /confirm  →  推进到下一步
       ↓
循环直至 POST /execute 返回 completed = true
```

---

## 二、整体架构

### 2.1 架构分层

```
┌──────────────────────────────────────────────┐
│              通信层：纯 REST API               │
├──────────────────────────────────────────────┤
│              路由层：tutorial_router.py        │
├──────────────────────────────────────────────┤
│  服务层：video_service / ai_service /         │
│          ocr_service / session_service        │
├──────────────────────────────────────────────┤
│  模型层：tutorial.py / ocr.py                 │
├──────────────────────────────────────────────┤
│  基础设施：SessionManager / TaskRunner         │
└──────────────────────────────────────────────┘
```

### 2.2 目录结构

```
backend/
├── main.py
├── config.py
├── requirements.txt
├── .env.example
│
├── models/
│   ├── __init__.py
│   ├── tutorial.py          # 教程会话 / 步骤 / 请求响应模型
│   └── ocr.py               # OCR 识别结果模型
│
├── routers/
│   ├── __init__.py
│   └── tutorial_router.py   # 全部 REST 端点
│
├── services/
│   ├── __init__.py
│   ├── video_service.py     # yt-dlp 视频下载
│   ├── ai_service.py        # OpenAI Vision 分析
│   ├── ocr_service.py       # EasyOCR 识别 + 坐标定位
│   └── session_service.py   # 步骤流程控制
│
├── infrastructure/
│   ├── __init__.py
│   ├── session_manager.py   # 内存会话存储
│   └── task_runner.py       # 后台异步任务
│
└── temp_downloads/           # 临时视频
```

---

## 三、REST API 设计

### 3.1 端点总览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/tutorial/create` | 提交链接，后台下载+分析 |
| GET | `/api/v1/tutorial/{id}/status` | 查询会话状态 |
| GET | `/api/v1/tutorial/{id}/steps` | 获取所有步骤 |
| POST | `/api/v1/tutorial/{id}/execute` | 获取当前步骤引导指令 |
| POST | `/api/v1/tutorial/{id}/screenshot` | 上传截图，OCR 返回坐标 |
| POST | `/api/v1/tutorial/{id}/confirm` | 确认完成，推进下一步 |
| POST | `/api/v1/tutorial/{id}/skip` | 跳过当前步骤 |
| DELETE | `/api/v1/tutorial/{id}` | 取消会话 |

---

### 3.2 接口详情

#### POST /create

```
Request:  { "url": "https://v.douyin.com/xxxxx/" }
Response: { "session_id": "uuid", "status": "processing", "message": "..." }
```

返回 202，后台异步执行下载+AI分析。

#### GET /{id}/status

```
Response: {
  "session_id": "...",
  "status": "ready",           // processing | ready | in_progress | completed | error
  "title": "小米手机去广告教程",
  "total_steps": 5,
  "current_step": 0,
  "steps": [
    { "index": 0, "instruction": "进入设置页面", "target_text": "设置",
      "page_description": "手机桌面主屏幕", "status": "pending" }
  ]
}
```

#### GET /{id}/steps

```
Response: {
  "session_id": "...",
  "title": "...",
  "steps": [...]
}
```

#### POST /{id}/execute

```
Request:  (无 body)
Response: {
  "completed": false,
  "step_index": 0,
  "total_steps": 5,
  "instruction": "进入设置页面，点击'设置'图标",
  "target_text": "设置",
  "page_description": "手机桌面主屏幕"
}
```

若全部完成则 `completed: true`。

#### POST /{id}/screenshot

```
Request:  {
  "step_index": 0,
  "image_base64": "iVBORw0KGgo...",
  "screen_width": 1080,
  "screen_height": 2340
}

Response (找到): {
  "step_index": 0,
  "found": true,
  "target_text": "设置",
  "bboxes": [
    { "text": "设置", "confidence": 0.95,
      "rect": { "left": 320, "top": 180, "width": 120, "height": 90 } }
  ],
  "all_texts": [ ... ],
  "suggestion": ""
}

Response (未找到): {
  "step_index": 0,
  "found": false,
  "target_text": "设置",
  "bboxes": [],
  "all_texts": [ ... ],
  "suggestion": "请确认当前页面，或尝试滑动页面"
}
```

#### POST /{id}/confirm

```
Request:  { "step_index": 0 }
Response: { "ok": true, "next_step": 1 }
```

#### POST /{id}/skip

```
Request:  { "step_index": 0, "reason": "..." }
Response: { "ok": true, "next_step": 1 }
```

---

### 3.3 交互时序

```
Client                              Server
  |                                    |
  |== POST /create (url) ============>|
  |<-- { session_id, status } --------|
  |                                    |  (后台下载+AI分析...)
  |== GET /status (轮询) ============>|
  |<-- { status: "ready" } -----------|
  |                                    |
  |== POST /execute =================>|
  |<-- { step_index: 0, target_text } -|
  |  (前端引导用户截图)                  |
  |                                    |
  |== POST /screenshot (base64) =====>|
  |                                    |  (OCR...)
  |<-- { found: true, bboxes } -------|
  |  (前端高亮目标区域)                  |
  |  (用户点击高亮区域)                  |
  |                                    |
  |== POST /confirm =================>|
  |<-- { ok: true } ------------------|
  |                                    |
  |== POST /execute =================>|   (下一步)
  |  ...                               |
```

---

## 四、数据模型

### 4.1 tutorial.py

```python
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
    page_description: str = ""
    status: str = "pending"          # pending | active | completed | skipped
    completed_at: datetime | None = None


class SessionStatus(str, Enum):
    PROCESSING = "processing"
    READY = "ready"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    ERROR = "error"


class TutorialSession(BaseModel):
    session_id: str
    title: str = ""
    platform: str = ""
    video_url: str = ""
    steps: list[TutorialStep] = []
    current_step_index: int = 0
    status: SessionStatus = SessionStatus.PROCESSING
    created_at: datetime = Field(default_factory=datetime.now)
    error_message: str = ""


# ---- Request / Response ----

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
```

### 4.2 ocr.py

```python
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
```

---

## 五、服务层设计

### 5.1 video_service.py

```
职责：平台检测 → 短链解析 → yt-dlp 下载 → 返回本地路径

VideoService.detect_platform(url: str) -> str
VideoService.resolve_url(raw: str) -> str
VideoService.download(url: str, session_id: str) -> str
```

实现要点：
- 迁移旧 `link_resolver.py` 的平台检测和下载参数逻辑
- 按 session_id 隔离目录：`temp_downloads/{session_id}/`
- 下载超时 120s，视频上限 500MB

### 5.2 ai_service.py

```
职责：ffmpeg 压缩+抽帧 → OpenAI Vision API → 返回步骤列表

AIService.analyze_video(video_path: str) -> tuple[str, list[dict]]
  # 返回 (title, [{instruction, target_text, page_description}])
```

系统提示词（关键输出字段）：

```
对每一步输出：
- instruction: 操作说明
- target_text: 需要点击的精确按钮/文字
- page_description: 所在页面描述

只返回 JSON，3~8 步。
```

### 5.3 ocr_service.py（EasyOCR）

```
职责：Base64 解码 → EasyOCR 识别 → 匹配 target_text → 返回坐标

OCRService.__init__(engine="easyocr", lang="ch_sim")
OCRService.recognize(image_base64: str, target_text: str, step_index: int) -> OCRResult
```

EasyOCR 集成伪码：

```python
import easyocr
from PIL import Image
import io, base64

class OCRService:
    def __init__(self, lang="ch_sim"):
        self._reader = easyocr.Reader([lang, "en"])

    def recognize(self, image_base64: str, target_text: str, step_index: int) -> OCRResult:
        img_bytes = base64.b64decode(image_base64)
        img = Image.open(io.BytesIO(img_bytes))
        img_np = numpy.array(img)

        results = self._reader.readtext(img_np, detail=1)
        all_texts = []
        matched = []

        for bbox, text, confidence in results:
            box = OCRTextBox(
                text=text,
                confidence=confidence,
                rect=RectModel(
                    left=bbox[0][0], top=bbox[0][1],
                    width=bbox[2][0] - bbox[0][0],
                    height=bbox[2][1] - bbox[0][1]
                )
            )
            all_texts.append(box)
            if target_text in text or text in target_text:
                matched.append(box)

        return OCRResult(
            step_index=step_index,
            found=len(matched) > 0,
            target_text=target_text,
            bboxes=sorted(matched, key=lambda x: x.confidence, reverse=True),
            all_texts=all_texts,
            suggestion="" if matched else "未找到目标文字，请确认当前页面"
        )
```

### 5.4 session_service.py

```
职责：步骤流程控制（纯状态机，不依赖 WS）

SessionService.get_current_step(session) -> ExecuteResponse
SessionService.handle_screenshot(session, request) -> OCRResult
SessionService.handle_confirm(session, step_index) -> StepActionResponse
SessionService.handle_skip(session, step_index, reason) -> StepActionResponse
```

状态机：

```
PROCESSING → READY → IN_PROGRESS ⇄ (screenshot → confirm → next)
                   → COMPLETED
                   → ERROR
```

---

## 六、基础设施层

### 6.1 session_manager.py

```
内存字典存储 TutorialSession，支持 TTL 过期（默认 30 分钟）
SessionManager.create(session) / get(id) / update(id, session) / delete(id)
```

### 6.2 task_runner.py

```
后台异步执行 video_service.download + ai_service.analyze
完成后更新 session 状态为 READY
使用 asyncio.create_task
```

---

## 七、路由层

```python
# tutorial_router.py

router = APIRouter(prefix="/api/v1/tutorial", tags=["tutorial"])

POST   /create              → create_tutorial
GET    /{session_id}/status → get_status
GET    /{session_id}/steps  → get_steps
POST   /{session_id}/execute    → execute_step
POST   /{session_id}/screenshot → upload_screenshot
POST   /{session_id}/confirm    → confirm_step
POST   /{session_id}/skip       → skip_step
DELETE /{session_id}        → cancel_tutorial
```

---

## 八、main.py

```python
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import tutorial_router
from infrastructure.session_manager import SessionManager

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.session_manager = SessionManager()
    app.state.ocr_service = None
    yield

app = FastAPI(title="AI Tutorial Backend", version="2.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])
app.include_router(tutorial_router.router)

@app.get("/")
async def root():
    return {"service": "AI Tutorial Backend", "version": "2.0.0", "status": "running"}
```

---

## 九、配置

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o"

    ocr_engine: str = "easyocr"    # easyocr | paddleocr
    ocr_lang: str = "ch_sim"

    session_ttl_seconds: int = 1800
    max_video_size_mb: int = 500
    video_download_timeout: int = 120

    class Config:
        env_file = ".env"
        env_prefix = ""

settings = Settings()
```

---

## 十、依赖

```
fastapi==0.136.1
uvicorn[standard]==0.47.0
python-multipart>=0.0.9

openai>=1.0.0

easyocr>=1.7.0

yt-dlp==2026.3.17

pydantic>=2.13.0
pydantic-settings>=2.0.0
python-dotenv>=1.0.0

Pillow>=10.0.0
numpy>=1.24.0
```

---

## 十一、开发阶段

### Phase 1：骨架 ✓（已完成）

- [x] 目录结构 + 全部 Pydantic 模型 + config + main.py

### Phase 2：REST API + 视频分析

- [ ] video_service.py（迁移旧下载逻辑）
- [ ] ai_service.py（迁移旧 ffmpeg 抽帧 + 新 Prompt）
- [ ] session_manager.py
- [ ] task_runner.py
- [ ] tutorial_router.py（/create、/status、/steps）
- [ ] 联调

### Phase 3：逐步引导 + OCR

- [ ] ocr_service.py（EasyOCR）
- [ ] session_service.py
- [ ] tutorial_router.py（/execute、/screenshot、/confirm、/skip）
- [ ] 联调

### Phase 4：完善

- [ ] 异常处理、会话 TTL 清理、日志
- [ ] 端到端测试

---

## 十二、设计决策

### 为什么用纯 REST 而非 WebSocket？

- DEMO 阶段交互本质是请求-响应，没有持续推送需求
- REST 零额外基础设施，curl/Postman 直接调试
- Flutter 端只需 `http` 包，不需要 `web_socket_channel`
- 后续如需实时推送，可以在不换架构的前提下加一个 WS 通道

### 为什么用 EasyOCR 而非 PaddleOCR？

- `pip install easyocr` 一分钟装完，不踩坑
- 中文识别准确率足够 DEMO 使用
- 体量 ~100MB vs PaddleOCR 500MB+
- 接口抽象好，后续一键切换引擎

### 为什么 OCR 坐标用绝对像素值？

- 前端传 screenshot 时附带 screen_width/height
- 像素坐标与截图一一对应，前端无需换算
