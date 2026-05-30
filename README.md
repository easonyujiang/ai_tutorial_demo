# AI Tutorial Demo

基于 AI 视觉识别的交互式教程助手 —— 粘贴视频链接，AI 自动解析操作步骤，在真实设备界面上逐步引导用户完成操作。

## 架构概览

```
┌──────────────┐       REST API        ┌──────────────────────┐
│   Flutter    │ ◄──────────────────► │   FastAPI Backend     │
│   Frontend   │    JSON over HTTP     │   (Python 3.12)      │
│  (Android)   │                       │                      │
│              │  ① POST /create       │  yt-dlp → 下载视频    │
│  粘贴链接 ───┼──────────────────────►│  ffmpeg → 压缩抽帧    │
│              │                       │  OpenAI → 解析步骤    │
│              │  ② GET /status        │                      │
│  轮询等待 ───┼──────────────────────►│                      │
│              │                       │                      │
│              │  ③ POST /execute      │  返回当前步骤引导      │
│  显示指引 ───┼──────────────────────►│                      │
│              │                       │                      │
│              │  ④ POST /screenshot   │  EasyOCR → 识别文字   │
│  截图上传 ───┼──────────────────────►│  返回高亮坐标          │
│              │                       │                      │
│              │  ⑤ POST /confirm      │  推进至下一步          │
│  用户确认 ───┼──────────────────────►│                      │
│              │       循环 ③-⑤         │                      │
└──────────────┘                       └──────────────────────┘
```

## 技术栈

| 层 | 技术 |
|---|------|
| 后端框架 | FastAPI + Uvicorn |
| AI 分析 | OpenAI Vision API（多模态） |
| OCR 引擎 | EasyOCR |
| 视频下载 | yt-dlp（支持抖音/B站/YouTube） |
| 视频处理 | ffmpeg + ffprobe |
| 前端框架 | Flutter 3.x（Android） |
| 通信协议 | REST API（JSON） |
| 容器化 | Docker + docker-compose |

## 目录结构

```
ai_tutorial_demo/
├── backend/                        # Python 后端
│   ├── main.py                     # FastAPI 入口
│   ├── config.py                   # pydantic-settings 配置
│   ├── Dockerfile                  # 容器构建文件
│   ├── requirements.txt            # Python 依赖
│   ├── .env.example                # 环境变量模板
│   ├── models/                     # Pydantic 数据模型
│   │   ├── tutorial.py             # 教程 / 步骤 / 请求响应模型
│   │   └── ocr.py                  # OCR 结果模型
│   ├── routers/
│   │   └── tutorial_router.py      # 全部 8 个 REST 端点
│   ├── services/
│   │   ├── video_service.py        # yt-dlp 视频下载
│   │   ├── ai_service.py           # OpenAI Vision 分析
│   │   ├── ocr_service.py          # EasyOCR 识别
│   │   └── session_service.py      # 步骤状态机
│   └── infrastructure/
│       ├── logger.py               # 统一日志配置
│       ├── session_manager.py      # 内存会话存储
│       └── task_runner.py          # 异步任务执行
│
├── frontend/                       # Flutter 前端
│   └── lib/
│       ├── main.dart
│       ├── config.dart             # 后端地址配置
│       ├── models/tutorial.dart    # 数据模型 + 响应模型
│       ├── screens/
│       │   ├── home_screen.dart    # 主页（粘贴链接）
│       │   ├── loading_screen.dart # 分析进度页
│       │   └── tutorial_screen.dart # 步骤引导页
│       ├── services/
│       │   ├── tutorial_service.dart # API 请求层
│       │   └── overlay_service.dart  # Android 原生通信
│       └── widgets/
│           ├── step_overlay.dart
│           └── instruction_bubble.dart
│
├── docs/
│   ├── backend-design.md           # 后端设计文档
│   └── api-reference.md            # 前端 API 参考
├── docker-compose.yml              # 一键部署编排
└── README.md
```

---

## 快速开始（本地开发）

### 前置要求

- Python 3.12+
- Flutter 3.x（Android SDK 已配置）
- ffmpeg / ffprobe（系统 PATH 中可用）
- OpenAI API Key

### 1. 启动后端

```bash
cd backend

# 创建虚拟环境（可选）
python -m venv venv
venv\Scripts\activate    # Windows
source venv/bin/activate  # macOS/Linux

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env，填入真实的 OPENAI_API_KEY 和 OPENAI_BASE_URL

# 启动服务
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

访问 http://localhost:8000/docs 查看 Swagger API 文档。

### 2. 启动前端

```bash
cd frontend

# 安装依赖
flutter pub get

# 修改后端地址（如需）
# 编辑 lib/config.dart 中的 backendUrl
# Android 模拟器默认使用 10.0.2.2 访问宿主机

# 运行
flutter run
```

### 3. 测试 API

```bash
# 健康检查
curl http://localhost:8000/

# 创建教程
curl -X POST http://localhost:8000/api/v1/tutorial/create \
  -H "Content-Type: application/json" \
  -d '{"url":"https://v.douyin.com/xxxxx"}'

# 查询状态
curl http://localhost:8000/api/v1/tutorial/{session_id}/status
```

---

## 服务器部署

### 方式一：Docker Compose（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/easonyujiang/ai_tutorial_demo.git
cd ai_tutorial_demo

# 2. 配置环境变量
cp backend/.env.example backend/.env
# 编辑 backend/.env，填入 OPENAI_API_KEY 等

# 3. 一键启动
docker compose up -d --build

# 4. 查看日志
docker compose logs -f backend

# 5. 停止
docker compose down
```

服务运行在 `http://<服务器IP>:8000`。

### 方式二：手动部署（Linux）

```bash
# 1. 安装系统依赖
sudo apt update
sudo apt install -y python3.12 python3.12-venv ffmpeg

# 2. 克隆项目
git clone https://github.com/easonyujiang/ai_tutorial_demo.git
cd ai_tutorial_demo/backend

# 3. 虚拟环境
python3.12 -m venv venv
source venv/bin/activate

# 4. 安装 Python 依赖
pip install -r requirements.txt

# 5. 配置
cp .env.example .env
vim .env  # 填入 API Key

# 6. 使用 Gunicorn + Uvicorn（推荐生产环境）
pip install gunicorn
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000 --daemon

# 或直接使用 Uvicorn
uvicorn main:app --host 0.0.0.0 --port 8000 &
```

### 方式三：Nginx 反向代理（生产推荐）

```nginx
server {
    listen 80;
    server_name your-domain.com;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }
}
```

---

## 环境变量

在 `backend/.env` 中配置：

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `OPENAI_API_KEY` | ✅ | — | OpenAI API 密钥 |
| `OPENAI_BASE_URL` | ✅ | `https://api.openai.com/v1` | API 端点地址 |
| `OPENAI_MODEL` | ❌ | `gpt-4o` | 使用的模型名称 |
| `OCR_ENGINE` | ❌ | `easyocr` | OCR 引擎（easyocr / paddleocr） |
| `OCR_LANG` | ❌ | `ch_sim` | OCR 识别语言 |
| `SESSION_TTL_SECONDS` | ❌ | `1800` | 会话过期时间（秒） |
| `MAX_VIDEO_SIZE_MB` | ❌ | `500` | 视频大小上限（MB） |

---

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/` | 健康检查 |
| `POST` | `/api/v1/tutorial/create` | 提交视频链接，后台分析 |
| `GET` | `/api/v1/tutorial/{id}/status` | 查询教程状态 |
| `GET` | `/api/v1/tutorial/{id}/steps` | 获取所有步骤 |
| `POST` | `/api/v1/tutorial/{id}/execute` | 执行当前步骤 |
| `POST` | `/api/v1/tutorial/{id}/screenshot` | 上传截图，OCR 返回坐标 |
| `POST` | `/api/v1/tutorial/{id}/confirm` | 确认步骤完成 |
| `POST` | `/api/v1/tutorial/{id}/skip` | 跳过当前步骤 |
| `DELETE` | `/api/v1/tutorial/{id}` | 取消会话 |

完整接口文档见 [docs/api-reference.md](docs/api-reference.md)，启动后端后可访问 Swagger：`http://localhost:8000/docs`

---

## 项目文档

- [后端设计文档](docs/backend-design.md) — 架构设计、分层说明、设计决策
- [API 接口文档](docs/api-reference.md) — 前端调用参考（含 Flutter 示例代码）

---

## 常见问题

### Q: 首次启动 EasyOCR 很慢？

首次调用会下载模型文件（~100MB），之后会缓存。服务器部署建议在 Docker 构建时预下载。

### Q: yt-dlp 下载失败？

某些平台可能需要 Cookie。将 Cookie 导出为 `cookies.txt`，在 `.env` 中配置：
```
DOUYIN_COOKIES_PATH=./cookies.txt
```

### Q: 如何切换 OCR 引擎？

在 `.env` 中设置 `OCR_ENGINE=paddleocr`，然后 `pip install paddlepaddle paddleocr`。

### Q: 前端如何连接远程后端？

编辑 `frontend/lib/config.dart`：
```dart
static const String backendUrl = 'http://你的服务器IP:8000';
```

或通过编译参数：
```bash
flutter run --dart-define=BACKEND_URL=http://192.168.1.100:8000
```
