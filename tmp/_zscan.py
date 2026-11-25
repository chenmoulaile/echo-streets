from PIL import Image
import numpy as np, glob, os
d = r"D:\mygame\assets\sprites\zombie_frames"
for p in sorted(glob.glob(os.path.join(d,"zombie_fodder_*.png"))):
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im)
    op = a[:,:,3] > 40
    ys,xs = np.nonzero(op)
    print("%-26s %dx%d  bbox x[%3d,%3d] y[%3d,%3d]  op=%5d"
          % (os.path.basename(p), im.size[0], im.size[1], xs.min(), xs.max(), ys.min(), ys.max(), op.sum()))
