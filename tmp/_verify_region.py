# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np, glob, os
# 分区统计：用 VmRebuild 的同一套 classify 判据，拆出 gun / skin / shirt 三块各自的明度分布
def classify(a):
    rgb = a[:,:,:3].astype(np.int32)
    r,g,b = rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
    mx = rgb.max(axis=2); mn = rgb.min(axis=2)
    lum = (r*299+g*587+b*114)//1000
    sat = np.where(mx>0, (mx-mn)*255//np.maximum(mx,1), 0)
    op = a[:,:,3]>40
    skin  = op & (r-b>28) & (r-g>12) & (lum>90) & (lum<235) & (sat<110)
    shirt = op & (lum>200) & (sat<45)
    navy  = op & (lum<100) & (b>r+18)
    gun   = op & ~skin & ~shirt & ~navy
    return gun, skin, shirt, navy, op, lum

for p in [r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png",
          r"D:\mygame\assets\sprites\viewmodel\vm_shotgun_idle.png"]:
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im)
    gun, skin, shirt, navy, op, lum = classify(a)
    n = int(op.sum())
    print("%s  opaque=%d" % (os.path.basename(p), n))
    for name, mask in [("gun(枪)",gun),("skin(手)",skin),("shirt(白袖)",shirt),("navy(深色)",navy)]:
        c = int(mask.sum())
        if c == 0:
            print("   %-12s 0 px" % name); continue
        L = lum[mask]
        print("   %-12s %6d px (%5.1f%%)  L均值=%3d  L<70占比=%5.1f%%  L>200占比=%5.1f%%"
              % (name, c, c/n*100, int(L.mean()), float((L<70).mean()*100), float((L>200).mean()*100)))
