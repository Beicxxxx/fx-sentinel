# 架构

## 目标

把「看中间价」「设心理价位提醒」「对近 90 日序列做情景解说」拆成两个进程，避免把爬虫、密钥和大模型调用全部塞进 APK。

```
手机 App (Flutter)
  ├─ HTTPS → Yahoo Finance chart     盘中报价（约 1–5 分钟级）
  ├─ HTTPS → api.frankfurter.app     失败时的 ECB 日频备源
  ├─ HTTPS → api.github.com          公开检查 Release，应用内下载 APK
  ├─ 本机 SharedPreferences          订阅列表、预警、可选 Token
  └─ 前台约 20 秒刷新并本地判定阈值

电脑 / 服务器 (Python)
  ├─ HTTPS → api.frankfurter.app
  ├─ 本地 JSON  bot/.data/store.json
  ├─ Telegram Bot API               /start /watch /predict 与推送
  └─ 可选 OpenAI 兼容 Chat Completions
```

两者 **不共享服务器**。v1 有意保持简单：App 可离线配置规则，但休眠后不可靠；要稳就用 Telegram 进程常驻。

## 行情

- App 优先请求 Yahoo Finance `BASEQUOTE=X` 的 5 分钟 K 线，取 `regularMarketPrice`。失败则回退 Frankfurter / ECB。
- 订阅列表存在本机；货币元数据见 `app/lib/currencies.dart`。
- 单位是 1 单位 base 兑 quote。公开行情可能有延迟，不是银行成交价。

## 预警

Telegram 侧：`evaluate()` 比较最新价与阈值，命中后按 `cooldown_hours`（默认 4 小时）抑制重复推送，并 `send_message` 到所有 `/start` 过的 `chat_id`。

App 侧：同样逻辑在 Dart 里实现，冷却 4 小时，只在应用进程活着时有效。

## 预测

1. App 按期限拉约 1 个月（7 日）或 6 个月（30 日）Yahoo 序列；机器人拉 90/180 日 ECB。
2. 计算近 5 日收益、相对 20 日均线、日波动。
3. 规则基线给出 `up | down | range`、置信度、分析要点、多空情景，并按 √t 画出预测中线与波动带。30 日变动约为 7 日的 1.7 倍并下调置信度。
4. 若存在 API Key，把统计交给 **通用** Chat Completions 模型（GPT / DeepSeek / 通义 / OpenRouter 等）。不存在可靠的汇率专用大模型。
5. 文案必须带免责声明；模型不得编造新闻。阴影区间不是保证。

## 字体

App 通过 `pubspec.yaml` 嵌入 `app/fonts/SarasaUiK-*.ttf` 子集。重新子集：`python3 scripts/subset_font.py`（需先解压官方 TTF 到 `/tmp/sarasa`）。
