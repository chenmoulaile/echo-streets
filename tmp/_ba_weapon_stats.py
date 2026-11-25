# -*- coding: utf-8 -*-
from PIL import Image
import os, glob, colorsys
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
files = sorted(glob.glob(os.path.join(d, "Weapon_Icon_*.png")))
print("total icons:", len(files))
rows = []
for f in files:
    im = Image.open(f).convert("RGBA")
    px = [p for p in im.getdata() if p[3] > 40]
    if not px: continue
    n = len(px)
    dark = sum(1 for p in px if max(p[:3]) < 70)          # 近黑
    gray = sum(1 for p in px if max(p[:3]) < 130 and (max(p[:3])-min(p[:3])) < 26)  # 中性深灰
    sat  = sum(1 for p in px if (max(p[:3])-min(p[:3])) >= 60)  # 高饱和（彩色装饰）
    rows.append((os.path.basename(f), n, dark/n, gray/n, sat/n))
import statistics as st
print("dark  mean %.1f%%  median %.1f%%" % (st.mean(r[2] for r in rows)*100, st.median(r[2] for r in rows)*100))
print("gray  mean %.1f%%" % (st.mean(r[3] for r in rows)*100))
print("sat   mean %.1f%%  median %.1f%%  max %.1f%%" % (st.mean(r[4] for r in rows)*100, st.median(r[4] for r in rows)*100, max(r[4] for r in rows)*100))
rows.sort(key=lambda r: r[4])
print("\n-- 最低彩色占比 5 张 --")
for r in rows[:5]: print("  %-24s dark=%5.1f%% sat=%5.1f%%" % (r[0], r[2]*100, r[4]*100))
print("-- 最高彩色占比 5 张 --")
for r in rows[-5:]: print("  %-24s dark=%5.1f%% sat=%5.1f%%" % (r[0], r[2]*100, r[4]*100))
