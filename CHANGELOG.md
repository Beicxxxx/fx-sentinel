# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 文档

- 补齐 README、许可证、架构说明与发布流程。
- 约定 GitHub `Beicxxxx/fx-sentinel` 为主仓；Origin 仓库名应对齐为 `fx-sentinel`。

## [1.0.0] - 2026-08-19

### 新增

- Flutter 安卓客户端：中间价看板、本机预警、7 日情景、设置项。
- Python Telegram 机器人：`/watch` 轮询推送、`/predict` 规则基线或可选大模型。
- GitHub Release `v1.0.0` 附带侧载 APK（调试签名）。

### 数据

- 行情源为 Frankfurter / ECB 日频中间价，不含银行牌价。

[Unreleased]: https://github.com/Beicxxxx/fx-sentinel/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Beicxxxx/fx-sentinel/releases/tag/v1.0.0
