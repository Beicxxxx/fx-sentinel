"""汇率哨兵：ECB 中间价客户端（Frankfurter）。"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass
from typing import Iterable

import httpx

FRANKFURTER = "https://api.frankfurter.app"

WATCHLIST = (
    ("USD", "CNY", "美元/人民币"),
    ("USD", "JPY", "美元/日元"),
    ("EUR", "USD", "欧元/美元"),
    ("GBP", "USD", "英镑/美元"),
    ("USD", "HKD", "美元/港元"),
    ("AUD", "USD", "澳元/美元"),
    ("USD", "KRW", "美元/韩元"),
)


@dataclass(frozen=True)
class Pair:
    base: str
    quote: str
    label: str

    @property
    def key(self) -> str:
        return f"{self.base}/{self.quote}"


PAIRS = tuple(Pair(*row) for row in WATCHLIST)
PAIR_BY_KEY = {p.key: p for p in PAIRS}


@dataclass
class Quote:
    pair: Pair
    rate: float
    date: str
    previous: float | None = None

    @property
    def change_pct(self) -> float | None:
        if self.previous in (None, 0):
            return None
        return (self.rate / self.previous - 1.0) * 100.0


@dataclass
class Series:
    pair: Pair
    points: list[tuple[str, float]]


def parse_pair(text: str) -> Pair:
    raw = text.strip().upper().replace(" ", "").replace("-", "/")
    if raw in PAIR_BY_KEY:
        return PAIR_BY_KEY[raw]
    if "/" not in raw:
        raise ValueError(f"无法识别货币对：{text}")
    base, quote = raw.split("/", 1)
    if not base or not quote:
        raise ValueError(f"无法识别货币对：{text}")
    known = PAIR_BY_KEY.get(f"{base}/{quote}")
    return known or Pair(base, quote, f"{base}/{quote}")


async def fetch_latest(client: httpx.AsyncClient, pairs: Iterable[Pair] | None = None) -> list[Quote]:
    targets = tuple(pairs or PAIRS)
    quotes: list[Quote] = []
    for pair in targets:
        latest = await _latest(client, pair)
        prev_date = _iso_days_ago(latest["date"], 7)
        hist = await _history(client, pair, prev_date, latest["date"])
        previous = _previous_value(hist, latest["date"])
        quotes.append(
            Quote(pair=pair, rate=float(latest["rate"]), date=latest["date"], previous=previous)
        )
    return quotes


async def fetch_history(
    client: httpx.AsyncClient, pair: Pair, days: int = 90
) -> Series:
    end = dt.date.today().isoformat()
    start = (dt.date.today() - dt.timedelta(days=days)).isoformat()
    points = await _history(client, pair, start, end)
    return Series(pair=pair, points=points)


async def _latest(client: httpx.AsyncClient, pair: Pair) -> dict:
    url = f"{FRANKFURTER}/latest"
    r = await client.get(url, params={"from": pair.base, "to": pair.quote})
    r.raise_for_status()
    data = r.json()
    rate = data["rates"][pair.quote]
    return {"date": data["date"], "rate": rate}


async def _history(
    client: httpx.AsyncClient, pair: Pair, start: str, end: str
) -> list[tuple[str, float]]:
    url = f"{FRANKFURTER}/{start}..{end}"
    r = await client.get(url, params={"from": pair.base, "to": pair.quote})
    r.raise_for_status()
    data = r.json()
    rates = data.get("rates") or {}
    points = [(day, float(vals[pair.quote])) for day, vals in sorted(rates.items())]
    return points


def _previous_value(points: list[tuple[str, float]], today: str) -> float | None:
    prior = [v for d, v in points if d < today]
    return prior[-1] if prior else (points[-2][1] if len(points) >= 2 else None)


def _iso_days_ago(iso: str, days: int) -> str:
    day = dt.date.fromisoformat(iso)
    return (day - dt.timedelta(days=days)).isoformat()


def format_rate(value: float) -> str:
    if value >= 100:
        return f"{value:,.2f}"
    if value >= 10:
        return f"{value:.4f}"
    return f"{value:.6f}".rstrip("0").rstrip(".")
