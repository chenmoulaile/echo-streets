# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np, glob, os
tot = 0
for p in sorted(glob.glob(r"D:\mygame\assets\sprites\viewmodel\*.png")):
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im).astype(np.int32)
    op = a[:,:,3] > 40
    r,g,b = a[:,:,0],a[:,:,1],a[:,:,2]
    cy = op & ((b-r)>60) & ((g-r)>40)
    n = int(cy.sum()); tot += n
    print("%-26s %s opaque=%6d 真青=%d" % (os.path.basename(p), im.size, op.sum(), n))
print("TOTAL cyan =", tot)
