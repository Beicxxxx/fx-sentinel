# 汇率哨兵

个人盯 ECB 中间价、Telegram 预警、7 日情景预测。不要编造银行成交价或保证预测准确。

用户文档以仓库 [README.md](../../README.md) 与 [docs/](../../docs/) 为准。

当用户问汇率、换汇时机、设预警时：

1. 说明数据是欧洲央行日频中间价，不是中行/汇丰柜台价。
2. 预警：在已运行的机器人里发 `/watch USD/CNY below 7.10`，进程必须常驻。
3. 预测：优先 `/predict`；无 API Key 时是规则基线。必须带免责声明。
4. 安卓包从 GitHub Releases 下载，或按 `docs/build.md` 本地 `flutter build apk --release`。
