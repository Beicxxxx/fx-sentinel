"""预警规则的本地 JSON 存储。"""

from __future__ import annotations

import json
import os
import uuid
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Literal

Condition = Literal["above", "below"]

DATA_DIR = Path(os.environ.get("FX_SENTINEL_DATA", Path(__file__).resolve().parent.parent / ".data"))


@dataclass
class Alert:
    id: str
    pair: str
    condition: Condition
    threshold: float
    enabled: bool = True
    cooldown_hours: float = 4.0
    last_fired_at: str | None = None
    created_at: str = ""


@dataclass
class Event:
    id: str
    alert_id: str
    pair: str
    rate: float
    message: str
    fired_at: str


@dataclass
class StoreData:
    alerts: list[Alert] = field(default_factory=list)
    events: list[Event] = field(default_factory=list)
    chat_ids: list[int] = field(default_factory=list)


class Store:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or (DATA_DIR / "store.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.data = StoreData()
        self.load()

    def load(self) -> None:
        if not self.path.exists():
            return
        raw = json.loads(self.path.read_text(encoding="utf-8"))
        self.data = StoreData(
            alerts=[Alert(**row) for row in raw.get("alerts", [])],
            events=[Event(**row) for row in raw.get("events", [])],
            chat_ids=[int(x) for x in raw.get("chat_ids", [])],
        )

    def save(self) -> None:
        payload = {
            "alerts": [asdict(a) for a in self.data.alerts],
            "events": [asdict(e) for e in self.data.events[-200:]],
            "chat_ids": self.data.chat_ids,
        }
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(self.path)

    def remember_chat(self, chat_id: int) -> None:
        if chat_id not in self.data.chat_ids:
            self.data.chat_ids.append(chat_id)
            self.save()

    def add_alert(self, pair: str, condition: Condition, threshold: float) -> Alert:
        import datetime as dt

        alert = Alert(
            id=uuid.uuid4().hex[:8],
            pair=pair,
            condition=condition,
            threshold=threshold,
            created_at=dt.datetime.now(dt.timezone.utc).isoformat(),
        )
        self.data.alerts.append(alert)
        self.save()
        return alert

    def remove_alert(self, alert_id: str) -> bool:
        before = len(self.data.alerts)
        self.data.alerts = [a for a in self.data.alerts if a.id != alert_id]
        if len(self.data.alerts) != before:
            self.save()
            return True
        return False

    def add_event(self, event: Event) -> None:
        self.data.events.append(event)
        self.save()
