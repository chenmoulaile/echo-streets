# -*- coding: utf-8 -*-
from PIL import Image
import os, collections
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
for n in ["Weapon_Icon_CH0263.png","Weapon_Icon_CH0075.png","Weapon_Icon_10017.png","Weapon_Icon_20008.png"]:
    p = os.path.join(d,n)
    if not os.path.exists(p):
        print(n, "MISSING"); continue
    im = Image.open(p).convert("RGBA")
    px = [q for q in im.getdata() if q[3]>40]
    tot = len(px)
    dark = sum(1 for q in px if max(q[:3])<70)
    sat  = sum(1 for q in px if (max(q[:3])-min(q[:3]))>=60)
    warm = sum(1 for q in px if q[0]>q[2]+18)
    rgb = [q[:3] for q in px]
    t = Image.new("RGB",(len(rgb),1)); t.putdata(rgb)
    q8 = t.quantize(colors=8, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q8.getpalette()[:24]; cnt = collections.Counter(q8.getdata())
    print("%-24s %s dark=%5.1f%% sat=%5.1f%% warm=%5.1f%%" % (n, im.size, dark/tot*100, sat/tot*100, warm/tot*100))
    for idx,c in cnt.most_common(6):
        r,g,b = pal[idx*3:idx*3+3]
        print("      %5.1f%%  rgb(%3d,%3d,%3d)" % (c/tot*100, r,g,b))
