# -*- coding: utf-8 -*-
from PIL import Image
import os, collections
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
# BA 画风量化：唯一色数、描边色、青色像素占比（判断哪些图带科幻元素）
for n in ["Weapon_Icon_CH0263.png","Weapon_Icon_13002.png","Weapon_Icon_10020.png",
          "Weapon_Icon_13000.png","Weapon_Icon_13010.png","Weapon_Icon_26002.png"]:
    p = os.path.join(d,n)
    im = Image.open(p).convert("RGBA")
    px = [q for q in im.getdata() if q[3]>40]
    tot = len(px)
    uniq = len(set(q[:3] for q in px))
    # 真青色（b-r>60 且 g-r>40）
    cy = sum(1 for q in px if q[2]-q[0]>60 and q[1]-q[0]>40)
    # 描边：极暗像素（max<25）
    out = sum(1 for q in px if max(q[:3])<25)
    # 白/亮（>230）
    hi = sum(1 for q in px if min(q[:3])>230)
    print("%-24s uniq=%5d  真青=%5.2f%%  极暗(描边)=%5.1f%%  亮白=%5.1f%%" % (n, uniq, cy/tot*100, out/tot*100, hi/tot*100))
