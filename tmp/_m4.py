import numpy as np
from PIL import Image

base = r"D:\mygame\tmp\shots"
# 枪口火光判据：高亮暖色（橙黄）
for n in ["01_idle.png","02_fire.png"]:
    a = np.asarray(Image.open(base+"\\"+n).convert("RGB")).astype(np.int32)
    r,g,b = a[:,:,0],a[:,:,1],a[:,:,2]
    flash = (r>190)&(g>120)&(g<230)&(b<130)&((r-b)>90)
    ys,xs = np.nonzero(flash)
    if len(xs)==0:
        print("%s flash=0" % n); continue
    print("%s flash=%d centroid=(%.1f,%.1f) bbox x[%d,%d] y[%d,%d]"
          % (n, len(xs), xs.mean(), ys.mean(), xs.min(), xs.max(), ys.min(), ys.max()))
print("expected muzzle screen pos = (219+13.3, 120+0) = (232.3, 120.0)")
