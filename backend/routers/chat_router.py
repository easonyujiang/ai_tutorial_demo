from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, Query
from pydantic import BaseModel

from infrastructure.logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])


class ChatTextRequest(BaseModel):
    text: str
    session_id: str | None = None


class ChatTextResponse(BaseModel):
    reply: str


@router.post("/text", response_model=ChatTextResponse)
async def chat_text(body: ChatTextRequest):
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="消息不能为空")

    if body.session_id:
        logger.info("Chat text for session=%s: %s", body.session_id, text)
    else:
        logger.info("Chat text (no session): %s", text)

    reply_templates = {
        "你好": "你好！我是 AI 教程助手。请粘贴一个视频链接，我会帮你分析并生成操作步骤。",
        "帮助": "你可以这样使用我：\n1. 粘贴视频链接 → 点击分析\n2. 教程就绪后 → 点击「开始教程」\n3. 按步骤操作 → 点击屏幕确认进入下一步",
        "谢谢": "不客气！有任何问题随时问我。",
    }

    reply = reply_templates.get(text, f"我已收到：{text}。你可以先粘贴视频链接点击分析，然后我会在教程里继续教你操作。")
    return ChatTextResponse(reply=reply)


@router.websocket("/voice-stream")
async def voice_stream(websocket: WebSocket, session_id: str = Query(default=None)):
    await websocket.accept()
    logger.info("Voice WebSocket connected, session=%s", session_id)

    try:
        await websocket.send_json({
            "type": "system",
            "text": "语音连接已建立。请在说话后松开按钮，我会用语音回复你。",
        })

        while True:
            raw = await websocket.receive()
            if "bytes" in raw:
                await websocket.send_json({
                    "type": "transcript",
                    "text": "（收到音频数据，语音识别中...）",
                })
                await websocket.send_json({
                    "type": "reply_text",
                    "text": "这是 AI 助手的语音回复。你可以继续说话，或粘贴视频链接让我帮你解析教程。",
                })
            elif "text" in raw:
                await websocket.send_json({
                    "type": "reply_text",
                    "text": f"收到文字消息：{raw['text']}",
                })

    except WebSocketDisconnect:
        logger.info("Voice WebSocket disconnected, session=%s", session_id)
    except Exception as e:
        logger.error("Voice WebSocket error: %s", e)
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except Exception:
            pass
