# 汇率哨兵

安卓 App + Telegram 机器人：盯 **ECB 日频中间价**、设阈值预警、用规则或大模型做 **7 日情景**（不是成交建议）。

第一期不做网页、不做中行/汇丰牌价、不做系统推送。预警靠 Telegram；App 负责看盘和预测。

## 你需要什么

- 安卓手机（Android 8+）
- 一台能联网的电脑跑机器人（预警才稳）
- Telegram 账号，向 [@BotFather](https://t.me/BotFather) 申请 bot token
- 可选：`OPENAI_API_KEY`（或兼容网关）。不填则预测走均线规则

## 安装安卓包

已安装 Flutter 与 Android SDK 时：

```bash
export PATH="$HOME/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
cd app
flutter pub get
flutter build apk --release
```

APK 在 `app/build/app/outputs/flutter-apk/app-release.apk`。传到手机直接安装。

## 跑 Telegram 机器人

```bash
cd bot
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example ../.env   # 填入 TELEGRAM_BOT_TOKEN
set -a && source ../.env && set +a
python main.py
```

在 Telegram 里找到你的机器人：

| 命令 | 作用 |
|---|---|
| `/start` | 绑定当前聊天，预警推到这里 |
| `/rates` | 关注列表中间价 |
| `/watch USD/CNY below 7.10` | 低于阈值提醒 |
| `/watch EUR/USD above 1.18` | 高于阈值提醒 |
| `/list` `/unwatch <id>` | 查看 / 删除 |
| `/predict USD/CNY` | 7 日情景 |

进程要一直开着。关掉电脑就不会推。可把 `python main.py` 放到 systemd / 开机脚本。

## App 里怎么用

1. **行情**：七个主要货币对、涨跌、90 日折线  
2. **预警**：可在手机里加规则（前台会检查）；休眠后不可靠，请用 Telegram `/watch`  
3. **预测**：规则基线；设置页填了 Key 则走大模型，失败回退基线  
4. **设置**：填机器人用户名（不含 `t.me`），方便跳转

## 字体

界面使用 **更纱黑体 UI K**（官方地区码是 `K`，即韩文地区汉字，对应你说的 KR）。授权 [SIL OFL 1.1](app/fonts/OFL.txt)，已按界面用字做子集。

K 字形按韩国汉字习惯，部分简体字观感会和国标不一样。若要更贴简体，以后可换成 `SarasaUiSC`。

## 数据与免责

- 行情：[Frankfurter](https://www.frankfurter.app/) 转欧洲央行参考价，通常滞后约一个交易日，**不是**汇丰/中行买卖价  
- 预测只吃价序列，不编新闻；**不构成投资或换汇建议**

## 仓库结构

```
app/     Flutter（Android 为主，Linux 仅供本机预览同一套界面）
bot/     Telegram 机器人
scripts/ 字体子集
```
