# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np
for p in [r"D:\mygame\tmp\rb_pistol.png", r"D:\mygame\tmp\rb_shotgun.png"]:
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im).astype(np.int32)
    op = a[:,:,3] > 40
    r,g,b = a[:,:,0],a[:,:,1],a[:,:,2]
    cy = op & ((b-r)>60) & ((g-r)>40)
    print("%-32s %s opaque=%d 真青=%d (%.2f%%)" % (p.split("\\")[-1], im.size, op.sum(), cy.sum(), cy.sum()/max(op.sum(),1)*100))
    # 打印新的高光像素样本
    hi = op & (r>110) & (abs(r-g)<15) & (abs(g-b)<20)
    print("   亮灰高光像素=%d" % hi.sum())
