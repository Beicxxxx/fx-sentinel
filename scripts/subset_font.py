#!/usr/bin/env python3
"""从源码抽出用到的字符，子集化更纱黑体 UI K。"""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SRC_FONTS = Path("/tmp/sarasa")
DST = ROOT / "app" / "fonts"
DST.mkdir(parents=True, exist_ok=True)

extra = (
    "汇率哨兵欧洲央行中间价银行柜台成交价关注列表美元人民币日元欧元英镑港元澳元韩元"
    "预警预测设置行情低于高于阈值心理价位应用内规则最近触发可靠推送走"
    "手机休眠检查不稳定电脑运行机器人发送打开还没有选一个货币对近个交易日"
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    ".,;:!?·%/+-_()[]{}<>@#&*'\"“”‘’—–…、，。：；？！￥"
)

chars = set(extra)
for folder in (ROOT / "app" / "lib", ROOT / "bot"):
    for path in folder.rglob("*"):
        if path.suffix in {".dart", ".py", ".md"}:
            chars.update(path.read_text(encoding="utf-8"))
text = "".join(sorted(c for c in chars if (c.isprintable() or c.isspace()) and c != "\n"))
(DST / "subset-chars.txt").write_text("".join(sorted(chars)), encoding="utf-8")

for weight in ("Regular", "Bold"):
    src = SRC_FONTS / f"SarasaUiK-{weight}.ttf"
    dst = DST / f"SarasaUiK-{weight}.ttf"
    subprocess.check_call(
        [
            "pyftsubset",
            str(src),
            f"--text-file={DST / 'subset-chars.txt'}",
            "--layout-features=*",
            "--no-hinting",
            f"--output-file={dst}",
        ]
    )
    print(weight, dst.stat().st_size)

ofl_src = ROOT / "third_party" / "fonts" / "OFL.txt"
if ofl_src.exists():
    shutil.copy(ofl_src, DST / "OFL.txt")
print("unique chars", len(chars))
