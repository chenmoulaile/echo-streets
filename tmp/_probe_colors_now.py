# -*- coding: utf-8 -*-
from PIL import Image
import os, glob
# 1) 现有落地 viewmodel 帧的配色分布
d = r"D:\mygame\assets\sprites\viewmodel"
print("=== 现有 viewmodel 落地帧 ===")
for n in ["vm_pistol_idle.png","vm_shotgun_idle.png"]:
    im = Image.open(os.path.join(d,n)).convert("RGBA")
    px = [p for p in im.getdata() if p[3] > 40]
    n_all = len(px)
    lum = [(p[0]*299+p[1]*587+p[2]*114)//1000 for p in px]
    dark = sum(1 for L in lum if L < 40)
    sat  = sum(1 for p in px if (max(p[:3])-min(p[:3])) >= 60)
    warm = sum(1 for p in px if p[0] > p[2]+18)   # 暖色（木/肤色）
    print("  %-20s %s opaque=%5d  L<40:%5.1f%%  sat>=60:%5.1f%%  warm:%5.1f%%" % (
        n, im.size, n_all, dark/n_all*100, sat/n_all*100, warm/n_all*100))

# 2) 源素材 Handgun 帧里那 54 个青色像素在哪
print("=== 源素材 Handgun__HandgunIdle.png 的青色像素位置 ===")
src = r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png"
im = Image.open(src).convert("RGBA")
w,h = im.size
cy = [(x,y,im.getpixel((x,y))) for y in range(h) for x in range(w)
      if im.getpixel((x,y))[3] > 40 and im.getpixel((x,y))[2] > 150
      and im.getpixel((x,y))[1] > 140 and im.getpixel((x,y))[0] < 140]
print("  count=%d  size=%dx%d" % (len(cy), w, h))
if cy:
    xs = [c[0] for c in cy]; ys = [c[1] for c in cy]
    print("  bbox x∈[%d,%d] y∈[%d,%d]" % (min(xs),max(xs),min(ys),max(ys)))
    print("  sample:", cy[:6])
