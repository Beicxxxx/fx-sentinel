# 汇率哨兵机器人

与安卓客户端配套的 Telegram 进程。从**仓库根目录**配置 `.env` 后：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..
set -a && source .env && set +a
cd bot && python main.py
```

逻辑在 `fx_sentinel/`：行情、本地存储、预警判定、预测。说明见 [docs/telegram.md](../docs/telegram.md)。
