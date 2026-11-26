"""列剖面诊断：定位 01_idle.png 里枪身像素的真实范围（区分背景误匹配）。"""
from PIL import Image
import numpy as np

im = np.asarray(Image.open(r"D:\mygame\tmp\shots\01_idle.png").convert("RGB")).astype(np.int32)
H, W, _ = im.shape
src = np.asarray(Image.open(
    r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png").convert("RGBA"))
mask = src[:, :, 3] > 40
uniq = np.unique(src[:, :, :3][mask].reshape(-1, 3), axis=0)

hit = np.zeros((H, W), dtype=bool)
for c in uniq:
    hit |= np.all(im == c, axis=2)

cols = hit.sum(axis=0)
print("column profile (cols with any match):")
runs = []
i = 0
while i < W:
    if cols[i] > 0:
        j = i
        while j + 1 < W and cols[j + 1] > 0:
            j += 1
        runs.append((i, j, int(cols[i:j + 1].sum()), int(cols[i:j + 1].max())))
        i = j + 1
    else:
        i += 1
print("  start end  total  max")
for r in runs:
    print("  %5d %4d %6d %5d" % r)

rows = hit.sum(axis=1)
nz = np.nonzero(rows)[0]
print("row extent: y[%d,%d]" % (nz.min(), nz.max()))
