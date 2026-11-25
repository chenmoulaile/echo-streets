import numpy as np
from PIL import Image

def bottom_span(path, alpha_from="A"):
    im = Image.open(path)
    a = np.asarray(im.convert("RGBA")).astype(np.int32)
    op = a[:,:,3] > 40
    ys,xs = np.nonzero(op)
    y0,y1 = ys.min(), ys.max()
    x0,x1 = xs.min(), xs.max()
    w = a.shape[1]; h = a.shape[0]
    row = op[y1]
    rx = np.nonzero(row)[0]
    print("%-46s canvas=%dx%d bbox x[%d,%d] y[%d,%d]" % (path.split("\\")[-1], w,h,x0,x1,y0,y1))
    print("   bottom row y=%d opaque x[%d,%d]  (rel bbox %.2f..%.2f)" % (y1, rx.min(), rx.max(), (rx.min()-x0)/max(1,(x1-x0)), (rx.max()-x0)/max(1,(x1-x0))))
    # top rows: muzzle
    top = op[y0:y0+6]
    tx = np.nonzero(top.any(axis=0))[0]
    print("   top rows x[%d,%d]  muzzle_frac_of_bbox=%.2f" % (tx.min(), tx.max(), (tx.mean()-x0)/max(1,(x1-x0))))

bottom_span(r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png")
bottom_span(r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png")
