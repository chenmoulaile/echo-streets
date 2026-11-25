# -*- coding: utf-8 -*-
from PIL import Image
import os
# 用严格判据重测：真青色 = 蓝绿明显高于红，且饱和度高
src = r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png"
im = Image.open(src).convert("RGBA")
w,h = im.size
def stats(pred, label):
    pts=[(x,y,im.getpixel((x,y))) for y in range(h) for x in range(w)
         if im.getpixel((x,y))[3]>40 and pred(im.getpixel((x,y)))]
    print("  %-28s count=%d" % (label, len(pts)))
    if pts:
        xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
        print("     bbox x∈[%d,%d] y∈[%d,%d]  sample=%s" % (min(xs),max(xs),min(ys),max(ys), pts[0][2]))
print("=== 源帧 %s %dx%d ===" % (os.path.basename(src), w, h))
stats(lambda p: p[2]>150 and p[1]>140 and p[0]<140, "旧判据 b>150 g>140 r<140")
stats(lambda p: p[2]-p[0]>60 and p[1]-p[0]>40 and p[1]>120, "真青色 b-r>60 且 g-r>40")
stats(lambda p: p[2]-p[0]>90 and p[1]>150 and p[0]<110, "强青 b-r>90 g>150 r<110")
