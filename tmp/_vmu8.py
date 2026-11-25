from PIL import Image
import numpy as np, os
d = r"D:\mygame\assets\sprites\viewmodel"
names = ["idle","fire1","reload1","reload2","reload3","reload4","draw"]
print("frame     gun_bbox                gun_cx  gun_cy  muzzle_hint")
for n in names:
    a = np.asarray(Image.open(os.path.join(d,"vm_pistol_%s.png"%n)).convert("RGBA")).astype(np.int32)
    r,g,b = a[:,:,0],a[:,:,1],a[:,:,2]
    op = a[:,:,3] > 40
    lum = (r*299+g*587+b*114)//1000
    sat = a[:,:,:3].max(axis=2)-a[:,:,:3].min(axis=2)
    skin = op & (r-b>28) & (r-g>12) & (lum>90) & (lum<235) & (sat<110)
    gun = op & ~skin
    ys,xs = np.nonzero(gun)
    top = ys.min()
    mz = xs[ys<=top+4].mean()
    print("%-8s x[%3d,%3d] y[%3d,%3d]  %6.1f  %6.1f  (%.1f,%d)" % (n, xs.min(), xs.max(), top, ys.max(), xs.mean(), ys.mean(), mz, top))
