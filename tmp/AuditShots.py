"""四章 24 张截帧的统计审计（每 3px 采样）。

输出 lum / sd / sat / white% / black%，用来对比材质像素化前后的基线。
white 判据 lum>=0.98（削顶），black 判据 lum<=0.02（死黑）。

用法: py -3 tmp/AuditShots.py [dir]
"""
import os
import sys

import numpy as np
from PIL import Image

d = sys.argv[1] if len(sys.argv) > 1 else r"D:\mygame\tmp\shots\chapter"


def stats(p):
    im = Image.open(p).convert("RGB")
    a = np.asarray(im).astype(np.int32)[::3, ::3]
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    L = (r * 299 + g * 587 + b * 114) / 255000.0
    mx = a.max(axis=2) / 255.0
    mn = a.min(axis=2) / 255.0
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return (L.mean(), L.std(), sat.mean(),
            100.0 * (L >= 0.98).mean(), 100.0 * (L <= 0.02).mean())


print("%-22s %6s %6s %6s %7s %7s" % ("shot", "lum", "sd", "sat", "white%", "black%"))
rows = []
for f in sorted(os.listdir(d)):
    if not f.endswith(".png") or f.startswith("_"):
        continue
    m, s, sa, w, bl = stats(os.path.join(d, f))
    rows.append((f[:-4], m, s, sa, w, bl))
    print("%-22s %6.3f %6.3f %6.3f %6.2f%% %6.2f%%" % (f[:-4], m, s, sa, w, bl))

if rows:
    print("\n范围 lum %.3f~%.3f  sd %.3f~%.3f  white max %.2f%%  black max %.2f%%" % (
        min(r[1] for r in rows), max(r[1] for r in rows),
        min(r[2] for r in rows), max(r[2] for r in rows),
        max(r[4] for r in rows), max(r[5] for r in rows)))
