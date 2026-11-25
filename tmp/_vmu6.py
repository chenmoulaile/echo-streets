from PIL import Image
import numpy as np, os
d = r"D:\mygame\assets\sprites\viewmodel"
for n in ("idle","reload2"):
    im = Image.open(os.path.join(d,"vm_pistol_%s.png"%n)).convert("RGBA")
    a = np.asarray(im).astype(np.int32)
    r,g,b = a[:,:,0],a[:,:,1],a[:,:,2]
    op = a[:,:,3] > 40
    lum = (r*299+g*587+b*114)//1000
    sat = a[:,:,:3].max(axis=2)-a[:,:,:3].min(axis=2)
    skin = op & (r-b>28) & (r-g>12) & (lum>90) & (lum<235) & (sat<110)
    gun = op & ~skin
    ys,xs = np.nonzero(gun)
    print("%s size=%s opaque=%d gun=%d gun_bbox x[%d,%d] y[%d,%d] gun_cx=%.1f gun_cy=%.1f"
          % (n, im.size, op.sum(), gun.sum(), xs.min(), xs.max(), ys.min(), ys.max(), xs.mean(), ys.mean()))
