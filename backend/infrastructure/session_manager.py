import time
import uuid
from threading import Lock

from models.tutorial import TutorialSession
from infrastructure.logger import get_logger

logger = get_logger(__name__)


class SessionManager:
    def __init__(self):
        self._sessions: dict[str, TutorialSession] = {}
        self._created_at: dict[str, float] = {}
        self._lock = Lock()

    def create(self, session: TutorialSession) -> str:
        if not session.session_id:
            session.session_id = uuid.uuid4().hex
        with self._lock:
            self._sessions[session.session_id] = session
            self._created_at[session.session_id] = time.time()
        logger.info("Session created: %s (total sessions: %d)",
                     session.session_id, len(self._sessions))
        return session.session_id

    def get(self, session_id: str) -> TutorialSession | None:
        self._cleanup_expired()
        with self._lock:
            session = self._sessions.get(session_id)
        if session:
            logger.debug("Session get: %s (status=%s)", session_id, session.status.value)
        else:
            logger.debug("Session get: %s -> NOT FOUND", session_id)
        return session

    def update(self, session_id: str, session: TutorialSession):
        with self._lock:
            self._sessions[session_id] = session
        logger.info("Session updated: %s (status=%s)", session_id, session.status.value)

    def delete(self, session_id: str):
        with self._lock:
            self._sessions.pop(session_id, None)
            self._created_at.pop(session_id, None)
        logger.info("Session deleted: %s (remaining: %d)",
                     session_id, len(self._sessions))

    def _cleanup_expired(self, ttl_seconds: int = 1800):
        now = time.time()
        with self._lock:
            expired = [
                sid for sid, ts in self._created_at.items()
                if now - ts > ttl_seconds
            ]
            for sid in expired:
                self._sessions.pop(sid, None)
                self._created_at.pop(sid, None)
        if expired:
            logger.info("Cleaned up %d expired sessions", len(expired))
