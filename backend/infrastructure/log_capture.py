import asyncio
import json
import logging
import time
from datetime import datetime


class LogCapture(logging.Handler):
    def __init__(self, capacity: int = 500):
        super().__init__()
        self._queue: asyncio.Queue[dict] = asyncio.Queue(maxsize=capacity)
        self._history: list[dict] = []
        self._capacity = capacity
        self.setFormatter(logging.Formatter("%(asctime)s | %(levelname)-7s | %(name)-22s | %(message)s", "%H:%M:%S"))

    def emit(self, record: logging.LogRecord):
        try:
            entry = {
                "time": self.formatter.formatTime(record, "%H:%M:%S"),
                "timestamp": datetime.now().isoformat(),
                "level": record.levelname,
                "logger": record.name,
                "message": self.format(record),
                "module": record.module,
                "lineno": record.lineno,
            }
            self._history.append(entry)
            if len(self._history) > self._capacity:
                self._history = self._history[-self._capacity:]

            try:
                self._queue.put_nowait(entry)
            except asyncio.QueueFull:
                self._queue.get_nowait()
                self._queue.put_nowait(entry)
        except Exception:
            pass

    async def stream(self):
        for entry in self._history:
            yield entry
        while True:
            try:
                entry = await asyncio.wait_for(self._queue.get(), timeout=1.0)
                yield entry
            except asyncio.TimeoutError:
                yield {"type": "heartbeat"}

    def get_history(self) -> list[dict]:
        return list(self._history)


_log_capture: LogCapture | None = None


def get_log_capture() -> LogCapture:
    global _log_capture
    if _log_capture is None:
        _log_capture = LogCapture(capacity=500)
        _log_capture.setLevel(logging.DEBUG)
        root = logging.getLogger()
        root.addHandler(_log_capture)
    return _log_capture
