# -*- coding: utf-8 -*-
from PIL import Image
import os
src = r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png"
im = Image.open(src).convert("RGBA")
print("src", im.size)
px = [p for p in im.getdata() if p[3] > 40]
cy = [p for p in px if p[2] > 150 and p[1] > 140 and p[0] < 140]
print("src opaque", len(px), "cyan", len(cy))
# 当前落地帧
d = r"D:\mygame\assets\sprites\viewmodel"
for n in sorted(os.listdir(d)):
    if not n.endswith(".png"): continue
    if not n.startswith("vm_pistol"): continue
    a = Image.open(os.path.join(d,n)).convert("RGBA")
    q = [p for p in a.getdata() if p[3] > 40]
    c = [p for p in q if p[2] > 150 and p[1] > 140 and p[0] < 140]
    print("%-22s %s opaque=%4d cyan=%3d" % (n, a.size, len(q), len(c)))
