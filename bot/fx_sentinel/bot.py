"""Telegram 汇率哨兵。"""

from __future__ import annotations

import asyncio
import logging
import os
import re

import httpx
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

from .alerts import evaluate
from .predict import baseline_forecast, forecast_to_text, llm_forecast, summarize
from .rates import fetch_history, fetch_latest, format_rate, parse_pair
from .store import Store

log = logging.getLogger("fx_sentinel")

HELP = """汇率哨兵 · ECB 中间价

/start 绑定本聊天，之后预警会推到这里
/rates 查看关注列表
/watch USD/CNY below 7.10
/watch EUR/USD above 1.18
/list 查看预警
/unwatch <id> 删除预警
/predict USD/CNY  7 日情景（有大模型 Key 则调用，否则规则基线）
/help

数据来自欧洲央行日频中间价，不是汇丰/中行柜台价，也不是实时 Tick。
预测不构成投资或换汇建议。"""


def _esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


class BotApp:
    def __init__(self) -> None:
        self.store = Store()
        self.http = httpx.AsyncClient(timeout=30.0)
        token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
        if not token:
            raise SystemExit("请设置环境变量 TELEGRAM_BOT_TOKEN")
        self.application = (
            Application.builder()
            .token(token)
            .post_init(self._on_start)
            .build()
        )
        self.application.add_handler(CommandHandler("start", self.start))
        self.application.add_handler(CommandHandler("help", self.help))
        self.application.add_handler(CommandHandler("rates", self.rates))
        self.application.add_handler(CommandHandler("watch", self.watch))
        self.application.add_handler(CommandHandler("list", self.list_alerts))
        self.application.add_handler(CommandHandler("unwatch", self.unwatch))
        self.application.add_handler(CommandHandler("predict", self.predict))
        self.application.add_handler(MessageHandler(filters.COMMAND, self.unknown))

    async def start(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        assert update.effective_chat
        self.store.remember_chat(update.effective_chat.id)
        extra = os.environ.get("OPENAI_API_KEY") and "已检测到大模型密钥，/predict 会走模型情景。" or "未配置 OPENAI_API_KEY，/predict 使用规则基线。"
        await update.message.reply_text(f"已绑定聊天 {update.effective_chat.id}。\n{extra}\n\n{HELP}")

    async def help(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        await update.message.reply_text(HELP)

    async def rates(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        try:
            quotes = await fetch_latest(self.http)
        except Exception as exc:
            await update.message.reply_text(f"拉取行情失败：{exc}")
            return
        lines = ["关注列表（ECB 中间价）"]
        for q in quotes:
            chg = ""
            if q.change_pct is not None:
                chg = f"  {q.change_pct:+.2f}%"
            lines.append(f"{q.pair.key}  {format_rate(q.rate)}{chg}  · {q.date}")
        await update.message.reply_text("\n".join(lines))

    async def watch(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        text = " ".join(context.args or [])
        parsed = _parse_watch(text)
        if not parsed:
            await update.message.reply_text("用法：/watch USD/CNY below 7.10")
            return
        pair, cond, threshold = parsed
        alert = self.store.add_alert(pair.key, cond, threshold)
        if update.effective_chat:
            self.store.remember_chat(update.effective_chat.id)
        cn = "高于" if cond == "above" else "低于"
        await update.message.reply_text(
            f"已添加预警 {alert.id}：{pair.key} {cn} {format_rate(threshold)}"
        )

    async def list_alerts(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not self.store.data.alerts:
            await update.message.reply_text("还没有预警。用 /watch USD/CNY below 7.10 添加。")
            return
        lines = []
        for a in self.store.data.alerts:
            cn = "高于" if a.condition == "above" else "低于"
            state = "开" if a.enabled else "关"
            lines.append(f"{a.id}  {a.pair} {cn} {format_rate(a.threshold)}  [{state}]")
        await update.message.reply_text("\n".join(lines))

    async def unwatch(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if not context.args:
            await update.message.reply_text("用法：/unwatch <id>")
            return
        ok = self.store.remove_alert(context.args[0])
        await update.message.reply_text("已删除。" if ok else "找不到这条预警。")

    async def predict(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        key = (context.args or ["USD/CNY"])[0]
        try:
            pair = parse_pair(key)
            series = await fetch_history(self.http, pair, days=90)
            stats = summarize(series)
            baseline = baseline_forecast(pair, stats)
            forecast = await llm_forecast(self.http, pair, stats, baseline)
        except Exception as exc:
            await update.message.reply_text(f"预测失败：{exc}")
            return
        await update.message.reply_text(forecast_to_text(forecast))

    async def unknown(self, update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        await update.message.reply_text("未知命令。发送 /help")

    async def poll_alerts(self) -> None:
        interval = int(os.environ.get("POLL_SECONDS", "60"))
        await asyncio.sleep(3)
        while True:
            try:
                if self.store.data.alerts:
                    quotes = await fetch_latest(self.http)
                    events = evaluate(self.store, quotes)
                    for event in events:
                        for chat_id in self.store.data.chat_ids:
                            await self.application.bot.send_message(chat_id, event.message)
                        log.info("fired %s", event.message)
            except Exception:
                log.exception("alert poll failed")
            await asyncio.sleep(max(30, interval))

    async def _on_start(self, app: Application) -> None:
        asyncio.create_task(self.poll_alerts())
        me = await app.bot.get_me()
        log.info("bot @%s ready", me.username)

    def run(self) -> None:
        logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
        extra = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
        if extra:
            try:
                self.store.remember_chat(int(extra))
            except ValueError:
                log.warning("TELEGRAM_CHAT_ID 不是整数，已忽略")
        self.application.run_polling()


def _parse_watch(text: str) -> tuple | None:
    m = re.match(
        r"^\s*([A-Za-z]{3}\s*/\s*[A-Za-z]{3})\s+(above|below|over|under|>|<)\s+([0-9]+(?:\.[0-9]+)?)\s*$",
        text,
        re.I,
    )
    if not m:
        return None
    pair = parse_pair(m.group(1))
    token = m.group(2).lower()
    cond = "above" if token in {"above", "over", ">"} else "below"
    return pair, cond, float(m.group(3))


def main() -> None:
    BotApp().run()


if __name__ == "__main__":
    main()
