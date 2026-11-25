import numpy as np
from PIL import Image

base = r"D:\mygame\tmp\shots"
names = ["01_idle.png","02_fire.png","03_reload.png","04_dead.png"]
prev = None
for n in names:
    im = Image.open(base + "\\" + n).convert("RGB")
    a = np.asarray(im).astype(np.int32)
    h, w, _ = a.shape
    # 只看右下角 viewmodel 区域，避开 HUD 文本与丧尸
    sub = a[100:270, 200:480]
    r,g,b = sub[:,:,0],sub[:,:,1],sub[:,:,2]
    lum = 0.299*r+0.587*g+0.114*b
    # 枪身：深色 + 低饱和
    mx = np.maximum(np.maximum(r,g),b); mn = np.minimum(np.minimum(r,g),b)
    sat = np.where(mx>0,(mx-mn)*255.0/np.maximum(mx,1),0)
    gun = (lum < 110) & (sat < 60)
    ys,xs = np.nonzero(gun)
    # 枪口火光：亮黄/亮橙
    flash = (r>200)&(g>150)&(b<150)
    print("%s  gun_px=%5d  bbox x[%d,%d] y[%d,%d] (rel 200/100)  flash_px=%d"
          % (n, gun.sum(), xs.min()+200, xs.max()+200, ys.min()+100, ys.max()+100, flash.sum()))
    if prev is not None and prev[0].shape == gun.shape:
        d = np.logical_xor(prev[0], gun).sum()
        print("      diff_vs_prev=%d" % d)
    prev = (gun, n)
