# -*- coding: utf-8 -*-
from PIL import Image
import os
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
# 确认 2xxxx 系列里哪些是霰弹枪（看轮廓：单管长枪管 + 泵柄）
# 先列出 2xxxx 的 dark/sat/warm，挑纯黑候选
import glob
cands = sorted(glob.glob(os.path.join(d,"Weapon_Icon_2*.png")))
print("2xxxx 系列共 %d 张" % len(cands))
rows=[]
for p in cands:
    im = Image.open(p).convert("RGBA")
    px = [q for q in im.getdata() if q[3]>40]
    if not px: continue
    n=len(px)
    dark=sum(1 for q in px if max(q[:3])<70)/n
    sat=sum(1 for q in px if (max(q[:3])-min(q[:3]))>=60)/n
    warm=sum(1 for q in px if q[0]>q[2]+18)/n
    rows.append((os.path.basename(p),dark,sat,warm))
rows.sort(key=lambda r:-r[1])
for r in rows[:12]:
    print("  %-24s dark=%5.1f%% sat=%5.1f%% warm=%5.1f%%" % (r[0],r[1]*100,r[2]*100,r[3]*100))
