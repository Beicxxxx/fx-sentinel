# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.4.0] - 2026-08-19

### 新增

- 预测页支持 7 日与 30 日情景，含分析要点、多空情景和历史+预测走势图。
- 设置页提供通用大模型预设（GPT / DeepSeek / 通义 / OpenRouter）。没有汇率专用模型。

### 变更

- Telegram `/predict` 可带 `30` 切换 30 日情景。

## [1.3.0] - 2026-08-19

### 变更

- 公开仓检查更新，不再需要 GitHub Token。
- 发现新版本后在应用内下载 APK 并调起系统安装。

## [1.2.0] - 2026-08-19

### 新增

- 扁平圆形国旗（circle-flags）。
- Revolut 风格走势详情页：大字报价、平滑面积图、1D–All 时段。

## [1.1.0] - 2026-08-19

### 新增

- 任意货币对订阅；Yahoo Finance 盘中报价，失败回退 ECB。
- 设置页检查更新，对照 GitHub Release。
- 货币对国旗徽章与卡片改版。

## [1.0.0] - 2026-08-19

### 新增

- Flutter 安卓客户端：中间价看板、本机预警、7 日情景、设置项。
- Python Telegram 机器人：`/watch` 轮询推送、`/predict` 规则基线或可选大模型。
- GitHub Release `v1.0.0` 附带侧载 APK（调试签名）。

### 数据

- 行情源为 Frankfurter / ECB 日频中间价，不含银行牌价。

[Unreleased]: https://github.com/Beicxxxx/fx-sentinel/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/Beicxxxx/fx-sentinel/releases/tag/v1.3.0
[1.2.0]: https://github.com/Beicxxxx/fx-sentinel/releases/tag/v1.2.0
[1.1.0]: https://github.com/Beicxxxx/fx-sentinel/releases/tag/v1.1.0
[1.0.0]: https://github.com/Beicxxxx/fx-sentinel/releases/tag/v1.0.0
