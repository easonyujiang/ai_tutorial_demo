import json
import os
import uuid
from datetime import datetime
from pathlib import Path
from threading import Lock

from pydantic import BaseModel

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
SKILLS_FILE = DATA_DIR / "skills.json"


class SkillStep(BaseModel):
    instruction: str
    target_text: str = ""
    target_description: str = ""
    target_type: str = "text"
    page_description: str = ""


class Skill(BaseModel):
    id: str = ""
    title: str
    description: str = ""
    device_allowlist: str = ""
    os_allowlist: str = ""
    launch_package: str = ""
    launch_activity: str = ""
    steps: list[SkillStep] = []
    created_at: str = ""
    updated_at: str = ""


class SkillStore:
    def __init__(self):
        self._lock = Lock()
        self._skills: dict[str, Skill] = {}
        self._load()

    def _load(self):
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        if SKILLS_FILE.exists():
            try:
                with open(SKILLS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                for item in data:
                    skill = Skill(**item)
                    self._skills[skill.id] = skill
            except Exception:
                self._skills = {}

    def _save(self):
        with self._lock:
            DATA_DIR.mkdir(parents=True, exist_ok=True)
            with open(SKILLS_FILE, "w", encoding="utf-8") as f:
                json.dump(
                    [s.model_dump() for s in self._skills.values()],
                    f, ensure_ascii=False, indent=2,
                )

    def list_all(self) -> list[Skill]:
        return sorted(self._skills.values(), key=lambda s: s.updated_at, reverse=True)

    def get(self, skill_id: str) -> Skill | None:
        return self._skills.get(skill_id)

    def create(self, skill: Skill) -> Skill:
        with self._lock:
            skill.id = uuid.uuid4().hex[:12]
            now = datetime.now().isoformat()
            skill.created_at = now
            skill.updated_at = now
            self._skills[skill.id] = skill
        self._save()
        return skill

    def update(self, skill_id: str, skill: Skill) -> Skill | None:
        with self._lock:
            if skill_id not in self._skills:
                return None
            skill.id = skill_id
            skill.updated_at = datetime.now().isoformat()
            skill.created_at = self._skills[skill_id].created_at
            self._skills[skill_id] = skill
        self._save()
        return skill

    def delete(self, skill_id: str) -> bool:
        with self._lock:
            if skill_id not in self._skills:
                return False
            del self._skills[skill_id]
        self._save()
        return True


_store: SkillStore | None = None


def get_skill_store() -> SkillStore:
    global _store
    if _store is None:
        _store = SkillStore()
    return _store
