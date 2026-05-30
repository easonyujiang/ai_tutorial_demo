import logging
import sys

LOG_FORMAT = "%(asctime)s | %(levelname)-7s | %(name)-22s | %(message)s"
DATE_FORMAT = "%H:%M:%S"


def setup_logging(level: int = logging.DEBUG):
    root = logging.getLogger()
    root.setLevel(level)

    if root.handlers:
        return

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(level)
    handler.setFormatter(logging.Formatter(LOG_FORMAT, DATE_FORMAT))
    root.addHandler(handler)

    logging.getLogger("yt_dlp").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("openai").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("easyocr").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
