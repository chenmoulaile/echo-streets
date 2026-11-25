import numpy as np
from PIL import Image
for name in ["vm_pistol_idle.png"]:
    p = r"D:\mygame\assets\sprites\viewmodel" + "\\" + name
    a = np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)
    op = a[:,:,3] > 40
    r,g,b = a[:,:,0],a[:,:,1],a[:,:,2]
    lum = 0.299*r + 0.587*g + 0.114*b
    mx = np.maximum(np.maximum(r,g),b); mn = np.minimum(np.minimum(r,g),b)
    sat = np.where(mx>0, (mx-mn)*255.0/np.maximum(mx,1), 0)
    skin = op & (r-b>28) & (r-g>12) & (lum>90) & (lum<235) & (sat<110)
    shirt = op & (lum>200) & (sat<45)
    navy = op & (lum<100) & (b>r+18)
    gun = op & ~skin & ~shirt & ~navy
    ys,xs = np.nonzero(op)
    print(name, "size=%dx%d" % (a.shape[1], a.shape[0]), "opaque=%d"%op.sum())
    print("  opaque bbox x[%d,%d] y[%d,%d]" % (xs.min(),xs.max(),ys.min(),ys.max()))
    for label, m in [("gun",gun),("skin",skin),("shirt",shirt),("navy",navy)]:
        if m.sum()==0:
            print("  %-5s 0 px" % label); continue
        yy,xx = np.nonzero(m)
        print("  %-5s %5d px  centroid=(%.1f,%.1f)  x[%d,%d]" % (label, m.sum(), xx.mean(), yy.mean(), xx.min(), xx.max()))
