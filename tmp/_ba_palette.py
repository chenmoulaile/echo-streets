# -*- coding: utf-8 -*-
from PIL import Image
import os, glob, collections
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
# 取 6 张最"黑"的真实枪械图标，提主色板（量化到 8 色看构成）
picks = ["Weapon_Icon_13000.png","Weapon_Icon_13002.png","Weapon_Icon_10020.png",
         "Weapon_Icon_26002.png","Weapon_Icon_13010.png","Weapon_Icon_10002.png"]
for n in picks:
    p = os.path.join(d,n)
    im = Image.open(p).convert("RGBA")
    px = [q[:3] for q in im.getdata() if q[3]>40]
    if not px: continue
    tmp = Image.new("RGB",(len(px),1)); tmp.putdata(px)
    q8 = tmp.quantize(colors=8, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q8.getpalette()[:24]
    cnt = collections.Counter(q8.getdata())
    print("%-24s" % n)
    for idx,c in cnt.most_common(8):
        r,g,b = pal[idx*3:idx*3+3]
        print("    %5.1f%%  rgb(%3d,%3d,%3d)  #%02X%02X%02X" % (c/len(px)*100, r,g,b, r,g,b))
