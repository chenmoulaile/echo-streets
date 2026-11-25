import numpy as np
from PIL import Image
import glob, os
d = r"D:\mygame\assets\sprites\viewmodel"
print("%-22s %-9s %-6s %s" % ("frame","size","maxRun","worst_col_x"))
for p in sorted(glob.glob(d+r"\vm_pistol_*.png")):
    a = np.asarray(Image.open(p).convert("RGBA"))
    op = a[:,:,3] > 0
    h,w = op.shape
    worst = 0; wx = -1
    for x in range(w):
        col = op[:,x]
        if not col.any(): continue
        ys = np.nonzero(col)[0]
        run = 1; best = 1
        for i in range(1, ys.size):
            if ys[i] == ys[i-1]+1:
                run += 1; best = max(best, run)
            else:
                run = 1
        if best > worst: worst, wx = best, x
    print("%-22s %dx%d   %3d/%3d  x=%d" % (os.path.basename(p), w, h, worst, h, wx))
