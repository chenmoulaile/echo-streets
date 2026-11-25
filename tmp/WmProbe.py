"""量水印区域的像素分布，为擦除定判据。"""
import numpy as np
from PIL import Image

im = Image.open(r"D:\mygame\trae-images\trae-20261125-123852-d9fe7d.jpg").convert("RGB")
a = np.asarray(im).astype(np.int16)

# 水印大致范围（上一轮探测结果）
x0, y0, x1, y1 = 1360, 1360, 1700, 1920
sub = a[y0:y1, x0:x1]
print("region", sub.shape)

lum = (sub[:, :, 0] * 299 + sub[:, :, 1] * 587 + sub[:, :, 2] * 114) // 1000
vals, counts = np.unique(lum, return_counts=True)
print("\n亮度直方图（前 20 个峰值）:")
order = np.argsort(-counts)[:20]
for i in sorted(order):
    print("  lum=%3d  n=%5d" % (vals[i], counts[i]))

# 取几行看具体色值
for y in (1400, 1500, 1600, 1700):
    row = a[y, x0:x1]
    uniq = {}
    for c in row:
        k = tuple(c)
        uniq[k] = uniq.get(k, 0) + 1
    top = sorted(uniq.items(), key=lambda kv: -kv[1])[:6]
    print("\ny=%d 主色:" % y, ", ".join("%s x%d" % (k, v) for k, v in top))
