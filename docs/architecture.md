# 架构

## 目标

把「看中间价」「设心理价位提醒」「对近 90 日序列做情景解说」拆成两个进程，避免把爬虫、密钥和大模型调用全部塞进 APK。

```
手机 App (Flutter)
  ├─ HTTPS → api.frankfurter.app   行情与历史
  ├─ 本机 SharedPreferences        预警规则、可选 LLM 配置
  └─ 前台定时刷新时本地判定阈值

电脑 / 服务器 (Python)
  ├─ HTTPS → api.frankfurter.app
  ├─ 本地 JSON  bot/.data/store.json
  ├─ Telegram Bot API               /start /watch /predict 与推送
  └─ 可选 OpenAI 兼容 Chat Completions
```

两者 **不共享服务器**。v1 有意保持简单：App 可离线配置规则，但休眠后不可靠；要稳就用 Telegram 进程常驻。

## 行情

- 客户端与机器人都请求 `https://api.frankfurter.app`。
- 货币对列表以 `bot/fx_sentinel/rates.py` 的 `WATCHLIST` 与 `app/lib/models.dart` 的 `watchlist` 为准，改动时两边一起改。
- 单位是 1 单位 base 兑 quote 的中间价，日期为 ECB 发布日，不是实时 Tick。

## 预警

Telegram 侧：`evaluate()` 比较最新价与阈值，命中后按 `cooldown_hours`（默认 4 小时）抑制重复推送，并 `send_message` 到所有 `/start` 过的 `chat_id`。

App 侧：同样逻辑在 Dart 里实现，冷却 4 小时，只在应用进程活着时有效。

## 预测

1. 拉约 90 日序列。
2. 计算近 5 日收益、相对 20 日均线、日波动。
3. 规则基线给出 `up | down | range`、置信度、简述。
4. 若存在 `OPENAI_API_KEY`（机器人环境或 App 设置），把统计特征交给模型，要求 JSON；解析失败则回退基线。
5. 文案必须带免责声明；模型不得编造新闻。

## 字体

App 通过 `pubspec.yaml` 嵌入 `app/fonts/SarasaUiK-*.ttf` 子集。重新子集：`python3 scripts/subset_font.py`（需先解压官方 TTF 到 `/tmp/sarasa`）。
