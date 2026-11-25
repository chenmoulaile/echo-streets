# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np, glob, os
print("%-26s %-10s %8s %6s %6s %6s %6s %6s" % ("file","size","opaque","dark%","gray%","sat60%","warm%","cyan"))
for p in sorted(glob.glob(r"D:\mygame\assets\sprites\viewmodel\*.png")):
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im).astype(np.int32)
    op = a[:,:,3] > 40
    n = int(op.sum())
    r = a[:,:,0][op]; g = a[:,:,1][op]; b = a[:,:,2][op]
    mx = np.maximum(np.maximum(r,g),b); mn = np.minimum(np.minimum(r,g),b)
    dark = float((mx<70).mean()*100); gray = float(((mx-mn)<25).mean()*100)
    sat = float(((mx-mn)>=60).mean()*100); warm = float(((r-b)>18).mean()*100)
    cy = int(((b-r)>60).__and__((g-r)>40).sum())
    print("%-26s %-10s %8d %6.1f %6.1f %6.1f %6.1f %6d" % (os.path.basename(p), "%dx%d"%im.size, n, dark, gray, sat, warm, cy))
