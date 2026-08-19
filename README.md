# 汇率哨兵（fx-sentinel）

个人用的汇率盯盘工具：**安卓客户端**看 ECB 中间价并做情景推演，**Telegram 机器人**负责阈值预警推送。

| | |
|---|---|
| 仓库 | https://github.com/Beicxxxx/fx-sentinel （主仓） |
| Origin | 应对齐为 `beichen-li/fx-sentinel`，见 [docs/remotes.md](docs/remotes.md) |
| 当前版本 | [v1.0.0](https://github.com/Beicxxxx/fx-sentinel/releases/tag/v1.0.0) |
| 平台 | Android 8+（App）、Python 3.12+（机器人） |
| 行情 | [Frankfurter](https://www.frankfurter.app/)（欧洲央行日频中间价） |
| 许可 | 代码 [MIT](LICENSE)；界面字体 [SIL OFL 1.1](NOTICE) |

**这不是交易软件。** 预测与预警仅供自己对照，不构成投资、换汇或任何交易建议。中间价不是银行柜台成交价。

---

## 功能与边界

**做了**

- 七个货币对的中间价、日涨跌、约 90 日折线
- 应用内阈值规则（应用在前台时检查）
- Telegram：`/watch` 预警、`/predict` 7 日情景、进程内轮询推送
- 无大模型密钥时用均线/波动率规则基线；有 OpenAI 兼容密钥则走模型，失败回退基线

**明确不做（v1）**

- 网页、登录、数据库
- 中行 / 汇丰等银行牌价
- 系统级推送（FCM）；休眠后的可靠提醒只走 Telegram
- Google Play 上架签名

更细的设计见 [docs/architecture.md](docs/architecture.md)。

---

## 安装 App

1. 打开 [Releases](https://github.com/Beicxxxx/fx-sentinel/releases)（私有仓需登录）。
2. 下载 `fx-sentinel-1.0.0.apk`。
3. 手机允许「安装未知应用」后安装。

当前 APK 使用 **调试签名**，只适合本人侧载。从源码打包见 [docs/build.md](docs/build.md)。

---

## 运行 Telegram 机器人

预警要有一台一直联网的机器跑进程。Token 只放在本地 `.env`，不要提交、不要发到聊天。

```bash
git clone https://github.com/Beicxxxx/fx-sentinel.git
cd fx-sentinel
python3 -m venv bot/.venv
source bot/.venv/bin/activate
pip install -r bot/requirements.txt
cp .env.example .env   # 编辑 TELEGRAM_BOT_TOKEN
set -a && source .env && set +a
cd bot && python main.py
```

向 [@BotFather](https://t.me/BotFather) 申请机器人后，在对话里发送：

| 命令 | 说明 |
|---|---|
| `/start` | 绑定当前 chat，之后预警推到这里 |
| `/rates` | 关注列表中间价 |
| `/watch USD/CNY below 7.10` | 低于阈值时提醒 |
| `/watch EUR/USD above 1.18` | 高于阈值时提醒 |
| `/list` / `/unwatch <id>` | 列出 / 删除规则 |
| `/predict USD/CNY` | 7 日情景 |
| `/help` | 命令说明 |

环境变量说明见 [.env.example](.env.example)。命令细节见 [docs/telegram.md](docs/telegram.md)。

---

## 仓库结构

```
app/                 Flutter 安卓客户端（Linux 仅用于同一套 UI 的本机预览）
bot/                 Telegram 机器人与行情/预警/预测逻辑
docs/                架构、构建、Telegram、安全
scripts/             字体子集等辅助脚本
third_party/fonts/   字体许可文本
```

---

## 开发

```bash
# 机器人单测
cd bot && PYTHONPATH=. python3 -m unittest discover -s tests -v

# 客户端
cd app && flutter test && flutter analyze
```

发布流程见 [docs/build.md](docs/build.md)。协作约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。变更记录见 [CHANGELOG.md](CHANGELOG.md)。

---

## 免责声明

行情来自欧洲央行参考价，通常滞后约一个交易日，不含银行点差与盘中 Tick。大模型输出禁止当作新闻或机构观点。使用本工具的任何换汇或交易决策由你自己承担。
