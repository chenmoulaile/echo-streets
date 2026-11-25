import numpy as np
from PIL import Image
import glob, os
d = r"D:\mygame\assets\sprites\viewmodel"
print("%-22s %s" % ("frame","extended columns: total / >6px / maxExt  (maxExt at x)"))
for p in sorted(glob.glob(d+r"\vm_pistol_*.png")):
    a = np.asarray(Image.open(p).convert("RGBA"))
    op = a[:,:,3] > 0
    h,w = op.shape
    ext = []
    for x in range(w):
        col = np.nonzero(op[:,x])[0]
        if col.size == 0:
            ext.append(0); continue
        ext.append(h-1-int(col[-1]))
    ext = np.array(ext)
    big = ext[ext>6]
    print("%-22s tot=%3d  big=%3d  max=%3d at x=%d" % (os.path.basename(p), int((ext>0).sum()), int(big.size), int(ext.max()), int(ext.argmax())))
