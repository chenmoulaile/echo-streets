from PIL import Image
import numpy as np, os
d = r"D:\mygame\assets\sprites\viewmodel"
names = ["idle","dry","fire1","fire2","fire3","reload1","reload2","reload3","reload4","draw"]
for n in names:
    p = os.path.join(d,"vm_pistol_%s.png"%n)
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im)
    op = a[:,:,3] > 40
    h,w = op.shape
    print("%-8s %dx%d  bottom_row=%3d  bottom4min=%3d  leftmost_col=%3d  opaque=%d"
          % (n, w, h, op[h-1].sum(), min(op[h-4+i].sum() for i in range(4)), op[:,0].sum(), op.sum()))
