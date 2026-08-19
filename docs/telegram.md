# Telegram 机器人

进程必须常驻。关掉终端或电脑后不会推送。可用 `systemd`、`tmux` 或开机脚本保活。

## 配置

从仓库根目录复制 `.env.example` 为 `.env`：

| 变量 | 必填 | 说明 |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | 是 | BotFather 颁发的 token |
| `TELEGRAM_CHAT_ID` | 否 | 预置接收预警的 chat；`/start` 也会写入本地存储 |
| `OPENAI_API_KEY` | 否 | 不填则 `/predict` 仅规则基线 |
| `OPENAI_BASE_URL` | 否 | 默认 `https://api.openai.com/v1` |
| `OPENAI_MODEL` | 否 | 默认 `gpt-4o-mini` |
| `POLL_SECONDS` | 否 | 预警轮询间隔，最小按代码限制不低于 30 秒 |
| `FX_SENTINEL_DATA` | 否 | 覆盖默认数据目录 `bot/.data` |

规则与事件保存在 `bot/.data/store.json`（已 gitignore）。

## 命令

- `/watch USD/CNY below 7.10` 与 `/watch EUR/USD above 1.18`
- 别名：`over`/`under`/`>`/`<`
- `/predict USD/CNY` 7 日情景；`/predict USD/CNY 30` 为 30 日。没有汇率专用模型，可选通用 Chat Completions。

未出现在关注列表里的 ECB 货币对也可以写（例如 `NZD/USD`），只要 Frankfurter 支持。
