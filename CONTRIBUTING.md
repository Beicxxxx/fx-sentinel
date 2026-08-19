# 贡献约定

本仓库目前是 **个人私有项目**。若你自己 fork 维护，请按下面做，避免再变成「只有一堆能跑的文件」。

## 提交

- `main` 保持可构建：机器人单测与 `flutter analyze` 应能过。
- 提交说明写清「改了什么、为什么」，不要只写 `update`。
- 不要提交 `.env`、token、密钥、完整未子集化字体包、`app/build/`。

## 文档

- 用户能直接操作的步骤写在根目录 [README.md](README.md)。
- 设计决策、数据流写在 [docs/architecture.md](docs/architecture.md)。
- 行为变化记入 [CHANGELOG.md](CHANGELOG.md) 的 `Unreleased`。

## 版本

- App 版本号在 `app/pubspec.yaml` 的 `version:`（`1.0.0+1` 中 `+1` 为 Android `versionCode`）。
- Git 标签与 Release 使用 `v主.次.修订`，与 CHANGELOG 章节一致。
- 出包步骤见 [docs/build.md](docs/build.md)。

## 安全

见 [docs/security.md](docs/security.md)。密钥只放本机环境变量，禁止写进仓库或聊天。
