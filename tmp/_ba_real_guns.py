# -*- coding: utf-8 -*-
from PIL import Image
import os, glob
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
files = sorted(glob.glob(os.path.join(d, "Weapon_Icon_*.png")))
# 只保留真实枪械命名（排除职业符号 AR/SR/HG/RG/SMG/MG 等纯符号）
real = [f for f in files if os.path.basename(f).startswith("Weapon_Icon_1") or
        os.path.basename(f).startswith("Weapon_Icon_2") or
        os.path.basename(f).startswith("Weapon_Icon_CH")]
print("真实枪械图标数:", len(real))
rows = []
for f in real:
    im = Image.open(f).convert("RGBA")
    px = [p for p in im.getdata() if p[3] > 40]
    if not px: continue
    n = len(px)
    dark = sum(1 for p in px if max(p[:3]) < 70)/n
    sat  = sum(1 for p in px if (max(p[:3])-min(p[:3])) >= 60)/n
    warm = sum(1 for p in px if p[0] > p[2]+18)/n
    rows.append((os.path.basename(f), n, dark, sat, warm))
import statistics as st
print("dark mean %.1f%% median %.1f%%" % (st.mean(r[2] for r in rows)*100, st.median(r[2] for r in rows)*100))
print("sat  mean %.1f%% median %.1f%%" % (st.mean(r[3] for r in rows)*100, st.median(r[3] for r in rows)*100))
print("\n-- 最黑（dark 最高）10 张，按 sat 升序 --")
rows.sort(key=lambda r: (-r[2]))
for r in rows[:10]:
    print("  %-26s dark=%5.1f%% sat=%5.1f%% warm=%5.1f%%" % (r[0], r[2]*100, r[3]*100, r[4]*100))
