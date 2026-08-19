"""根据最新中间价判定预警是否触发。"""

from __future__ import annotations

import datetime as dt
import uuid

from .rates import Quote, format_rate
from .store import Event, Store


def evaluate(store: Store, quotes: list[Quote]) -> list[Event]:
    by_key = {q.pair.key: q for q in quotes}
    now = dt.datetime.now(dt.timezone.utc)
    fired: list[Event] = []
    for alert in store.data.alerts:
        if not alert.enabled:
            continue
        quote = by_key.get(alert.pair)
        if quote is None:
            continue
        hit = (
            alert.condition == "above"
            and quote.rate >= alert.threshold
            or alert.condition == "below"
            and quote.rate <= alert.threshold
        )
        if not hit:
            continue
        if alert.last_fired_at:
            last = dt.datetime.fromisoformat(alert.last_fired_at)
            elapsed = (now - last).total_seconds() / 3600
            if elapsed < alert.cooldown_hours:
                continue
        cond = "高于" if alert.condition == "above" else "低于"
        message = (
            f"预警触发：{alert.pair} 现价 {format_rate(quote.rate)} "
            f"已{cond}阈值 {format_rate(alert.threshold)}（ECB 中间价，日期 {quote.date}）"
        )
        event = Event(
            id=uuid.uuid4().hex[:10],
            alert_id=alert.id,
            pair=alert.pair,
            rate=quote.rate,
            message=message,
            fired_at=now.isoformat(),
        )
        alert.last_fired_at = event.fired_at
        store.add_event(event)
        fired.append(event)
    if fired:
        store.save()
    return fired
