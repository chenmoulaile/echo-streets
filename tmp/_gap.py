import numpy as np
from PIL import Image
import glob, os
d = r"D:\mygame\assets\sprites\viewmodel"
for p in sorted(glob.glob(d+r"\vm_pistol_*.png")):
    a = np.asarray(Image.open(p).convert("RGBA"))
    op = a[:,:,3] > 40
    ys,xs = np.nonzero(op)
    h,w = op.shape
    bot = op[h-1].sum()
    print("%-22s %dx%d  bbox y[%d,%d]  bottom_row_px=%3d  top_row_px=%3d"
          % (os.path.basename(p), w, h, ys.min(), ys.max(), bot, op[0].sum()))
