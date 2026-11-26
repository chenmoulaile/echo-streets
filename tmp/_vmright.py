"""定位截图右侧多出来的 6px：输出 x∈[400,420] 区域的命中行与颜色。"""
from PIL import Image
import numpy as np

im = np.asarray(Image.open(r"D:\mygame\tmp\shots\01_idle.png").convert("RGB")).astype(np.int32)
src = np.asarray(Image.open(
    r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png").convert("RGBA"))
mask = src[:, :, 3] > 40
uniq = np.unique(src[:, :, :3][mask].reshape(-1, 3), axis=0)
hit = np.zeros(im.shape[:2], dtype=bool)
for c in uniq:
    hit |= np.all(im == c, axis=2)

for x in range(404, 416):
    ys = np.nonzero(hit[:, x])[0]
    if len(ys):
        cols = {tuple(im[y, x]) for y in ys}
        print("x=%d  rows=%d  y[%d,%d]  colors=%s" % (
            x, len(ys), ys.min(), ys.max(), sorted(cols)[:4]))
    else:
        print("x=%d  none" % x)

print()
print("body column fill (x=270..300 sample):")
for x in (267, 270, 300, 350, 380, 400, 406, 407, 410, 412):
    ys = np.nonzero(hit[:, x])[0]
    print("  x=%d rows=%d %s" % (x, len(ys), ("y[%d,%d]" % (ys.min(), ys.max())) if len(ys) else ""))
