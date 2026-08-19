"""统计特征 + 可选大模型情景预测。无 Key 时使用规则基线。"""

from __future__ import annotations

import json
import os
import statistics
from dataclasses import dataclass, asdict
from typing import Any

import httpx

from .rates import Pair, Series, format_rate


@dataclass
class Forecast:
    pair: str
    horizon: str
    horizon_days: int
    direction: str
    confidence: int
    predicted_change_pct: float
    narrative: str
    analysis: list[str]
    risks: list[str]
    bull_case: str
    bear_case: str
    disclaimer: str
    source: str
    stats: dict[str, Any]


def summarize(series: Series) -> dict[str, Any]:
    values = [v for _, v in series.points]
    if len(values) < 5:
        raise ValueError("历史数据不足，无法预测。")
    last = values[-1]
    window5 = values[-5:]
    window20 = values[-20:] if len(values) >= 20 else values
    ret5 = (last / window5[0] - 1) * 100
    ma20 = sum(window20) / len(window20)
    rets = [(values[i] / values[i - 1] - 1) * 100 for i in range(1, len(values))]
    vol = statistics.pstdev(rets) if len(rets) > 1 else 0.0
    high = max(values)
    low = min(values)
    return {
        "last": last,
        "last_fmt": format_rate(last),
        "ret5_pct": round(ret5, 4),
        "ma20": round(ma20, 6),
        "vs_ma20_pct": round((last / ma20 - 1) * 100, 4),
        "vol_pct": round(vol, 4),
        "high": high,
        "low": low,
        "n": len(values),
        "start": series.points[0][0],
        "end": series.points[-1][0],
    }


def baseline_forecast(pair: Pair, stats: dict[str, Any], horizon_days: int = 7) -> Forecast:
    days = 30 if horizon_days >= 30 else 7
    ret5 = stats["ret5_pct"]
    vs_ma = stats["vs_ma20_pct"]
    vol = max(stats["vol_pct"], 0.05)
    if ret5 > 0.35 and vs_ma > 0:
        direction = "up"
        change = min(abs(ret5) * 0.4, vol * 2)
    elif ret5 < -0.35 and vs_ma < 0:
        direction = "down"
        change = -min(abs(ret5) * 0.4, vol * 2)
    else:
        direction = "range"
        change = 0.0
    confidence = int(max(28, min(62, 55 - vol * 8 + abs(vs_ma))))
    if days >= 30:
        change *= 1.7
        confidence = int(max(18, min(48, confidence * 0.72)))
    narrative = (
        f"{pair.key} 近 5 个交易日变动 {ret5:+.2f}%，相对 20 日均线 {vs_ma:+.2f}%。"
        f"日波动约 {vol:.2f}%。规则基线判断未来约 {days} 日偏向「{_dir_cn(direction)}」，"
        "这只是对已有中间价序列的外推，不是对新闻或央行操作的定价。"
    )
    analysis = [
        f"近 5 日收益 {ret5:+.2f}%",
        f"相对 20 日均线 {vs_ma:+.2f}%",
        f"日波动约 {vol:.2f}%，{days} 日不确定性随时间放大",
        "没有汇率专用大模型，语言模型只会解说这些统计",
    ]
    bull = "若动量延续，报价可能靠近偏多一侧。" if direction != "down" else "若超卖后回归均线，短线可能反弹。"
    bear = "若事件冲击或动量衰竭，价格可能跌破近端区间。" if direction != "up" else "若下跌延续，下沿以外仍可能被击穿。"
    return Forecast(
        pair=pair.key,
        horizon=f"{days}d",
        horizon_days=days,
        direction=direction,
        confidence=confidence,
        predicted_change_pct=round(change, 3),
        narrative=narrative,
        analysis=analysis,
        risks=[
            "ECB 日频中间价不含银行点差与盘中波动",
            "突发利率决议、风险情绪转向会使方向立刻失效",
            "区间市中趋势规则容易来回打脸",
        ],
        bull_case=bull,
        bear_case=bear,
        disclaimer="预测仅供学习研究，不构成任何投资、换汇或交易建议。",
        source="baseline",
        stats=stats,
    )


async def llm_forecast(
    client: httpx.AsyncClient,
    pair: Pair,
    stats: dict[str, Any],
    baseline: Forecast,
) -> Forecast:
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        return baseline
    days = baseline.horizon_days
    base_url = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")
    schema = {
        "direction": "up | down | range",
        "confidence": "整数 0-100",
        "predicted_change_pct": f"未来约{days}日相对现价的预估变动百分比，区间市接近0",
        "narrative": "不超过180字中文，只用所给统计，禁止编造新闻",
        "analysis": ["3到5条分析"],
        "risks": ["三条以内风险"],
        "bull_case": "偏多情景一句",
        "bear_case": "偏空情景一句",
    }
    prompt = (
        f"你是汇率情景解说员，不是荐股机器人。只根据下列统计做 {days} 日情景。"
        "禁止编造数据、新闻或机构观点。输出 JSON 对象，键如下：\n"
        f"{json.dumps(schema, ensure_ascii=False)}\n\n"
        f"货币对: {pair.key} ({pair.label})\n统计: {json.dumps(stats, ensure_ascii=False)}"
    )
    r = await client.post(
        f"{base_url}/chat/completions",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json={
            "model": model,
            "temperature": 0.3,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": "只输出合法 JSON。"},
                {"role": "user", "content": prompt},
            ],
        },
        timeout=40.0,
    )
    r.raise_for_status()
    content = r.json()["choices"][0]["message"]["content"]
    parsed = json.loads(content)
    direction = str(parsed.get("direction", baseline.direction)).lower()
    if direction not in {"up", "down", "range"}:
        direction = baseline.direction
    try:
        confidence = int(parsed.get("confidence", baseline.confidence))
    except (TypeError, ValueError):
        confidence = baseline.confidence
    try:
        change = float(parsed.get("predicted_change_pct", baseline.predicted_change_pct))
    except (TypeError, ValueError):
        change = baseline.predicted_change_pct
    risks = parsed.get("risks") or baseline.risks
    if isinstance(risks, str):
        risks = [risks]
    analysis = parsed.get("analysis") or baseline.analysis
    if isinstance(analysis, str):
        analysis = [analysis]
    narrative = str(parsed.get("narrative") or baseline.narrative)
    return Forecast(
        pair=pair.key,
        horizon=f"{days}d",
        horizon_days=days,
        direction=direction,
        confidence=max(0, min(100, confidence)),
        predicted_change_pct=round(change, 3),
        narrative=narrative.strip(),
        analysis=[str(x) for x in analysis][:6],
        risks=[str(x) for x in risks][:4],
        bull_case=str(parsed.get("bull_case") or baseline.bull_case).strip(),
        bear_case=str(parsed.get("bear_case") or baseline.bear_case).strip(),
        disclaimer=baseline.disclaimer,
        source="llm",
        stats=stats,
    )


def _dir_cn(direction: str) -> str:
    return {"up": "上行", "down": "下行", "range": "震荡"}.get(direction, direction)


def forecast_to_text(forecast: Forecast) -> str:
    arrow = {"up": "上行", "down": "下行", "range": "震荡"}.get(forecast.direction, forecast.direction)
    src = "大模型情景" if forecast.source == "llm" else "规则基线"
    analysis = "\n".join(f"· {r}" for r in forecast.analysis)
    risks = "\n".join(f"· {r}" for r in forecast.risks)
    return (
        f"{forecast.pair} · {forecast.horizon_days} 日情景（{src}）\n"
        f"方向：{arrow}　置信度：{forecast.confidence}%　预估变动：{forecast.predicted_change_pct:+.2f}%\n"
        f"现价：{forecast.stats.get('last_fmt')}　样本：{forecast.stats.get('start')} → {forecast.stats.get('end')}\n\n"
        f"{forecast.narrative}\n\n分析：\n{analysis}\n\n"
        f"偏多：{forecast.bull_case}\n偏空：{forecast.bear_case}\n\n"
        f"风险：\n{risks}\n\n{forecast.disclaimer}"
    )


def as_public_dict(forecast: Forecast) -> dict[str, Any]:
    return asdict(forecast)
