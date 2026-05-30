import base64
import io
import threading

import easyocr
import numpy as np
from PIL import Image

from config import settings
from infrastructure.logger import get_logger
from models.ocr import OCRResult, OCRTextBox
from models.tutorial import RectModel

logger = get_logger(__name__)

_reader: easyocr.Reader | None = None
_reader_lock = threading.Lock()


def _get_reader() -> easyocr.Reader:
    global _reader
    if _reader is None:
        with _reader_lock:
            if _reader is None:
                lang = settings.ocr_lang or "ch_sim"
                logger.info("Initializing EasyOCR (lang=%s, gpu=False)...", lang)
                _reader = easyocr.Reader([lang, "en"], gpu=False)
                logger.info("EasyOCR initialized")
    return _reader


def recognize(image_base64: str, target_text: str, step_index: int) -> OCRResult:
    logger.debug(
        "OCR recognize: step=%d, target='%s', image_size=%d chars",
        step_index, target_text, len(image_base64),
    )

    reader = _get_reader()

    img_bytes = base64.b64decode(image_base64)
    img = Image.open(io.BytesIO(img_bytes))
    img_np = np.array(img)

    logger.debug("Image decoded: %dx%d", img.width, img.height)

    results = reader.readtext(img_np, detail=1)
    logger.info("OCR detected %d text regions", len(results))

    all_texts: list[OCRTextBox] = []
    matched: list[OCRTextBox] = []

    for bbox, text, confidence in results:
        if not text or not text.strip():
            continue

        box = OCRTextBox(
            text=text.strip(),
            confidence=round(float(confidence), 4),
            rect=RectModel(
                left=float(bbox[0][0]),
                top=float(bbox[0][1]),
                width=float(bbox[2][0] - bbox[0][0]),
                height=float(bbox[2][1] - bbox[0][1]),
            ),
        )
        all_texts.append(box)

        if target_text and (target_text in text or text in target_text):
            matched.append(box)
            logger.debug(
                "Match found: text='%s', confidence=%.2f%%, rect=(%.0f,%.0f,%.0f,%.0f)",
                text, confidence * 100,
                box.rect.left, box.rect.top, box.rect.width, box.rect.height,
            )

    matched.sort(key=lambda x: x.confidence, reverse=True)

    if matched:
        suggestion = ""
        logger.info(
            "OCR result: FOUND target='%s', matches=%d (top confidence=%.2f%%)",
            target_text, len(matched), matched[0].confidence * 100,
        )
    elif not target_text:
        suggestion = "未指定目标文字"
        logger.warning("OCR: no target_text specified")
    else:
        suggestion = "未找到目标文字，请确认当前页面是否正确"
        texts_found = [t.text for t in all_texts[:20]]
        logger.warning(
            "OCR: target='%s' NOT FOUND among %d texts. Top texts: %s",
            target_text, len(all_texts), texts_found,
        )

    return OCRResult(
        step_index=step_index,
        found=len(matched) > 0,
        target_text=target_text,
        bboxes=matched,
        all_texts=all_texts,
        suggestion=suggestion,
    )
