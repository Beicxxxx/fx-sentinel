# 安全

## 密钥

- `.env`、token、API Key **禁止提交**（已在 `.gitignore`）。
- **禁止把 GitHub PAT、Bot token 发到聊天、Issue、截图。** 一旦发出去，立即在颁发方作废并换新。
- App 设置里的大模型密钥存在手机本地 `SharedPreferences`，卸载即失，也不会上传到本仓库的服务器（v1 没有自建后端）。

## 安装包

- Release 里的 APK 为调试签名，仅本人侧载。
- 不要把未签名或调试签名的包当正式分发渠道。

## 数据

- 不采集用户账号；Telegram `chat_id` 只写在运行机器人的那台机器上。
- 行情来自第三方公开 API，可用性取决于 Frankfurter / ECB。
