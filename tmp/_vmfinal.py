"""最终几何复核：在 01_idle.png 上直接量枪口屏幕 x 与枪身左右边界，
排除背景同色误匹配（右侧 406..412 的纯黑行是墙上的暗线）。"""
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

# 枪身 = 最大的连通列块（267..405）；逐列取命中行数 >= 3 视为枪身列
cols = hit.sum(axis=0)
body_cols = np.nonzero(cols >= 3)[0]
x0, x1 = int(body_cols.min()), int(body_cols.max())
print("gun body columns x[%d,%d]  left=%.2f%%  right=%.2f%%" % (
    x0, x1, x0 / W * 100.0, x1 / W * 100.0))

rows = hit.sum(axis=1)
top = int(np.nonzero(rows >= 3)[0].min())
print("gun top row y=%d (predicted 82+32=114)" % top)

# 枪口 = 顶行上枪身列的横向中心
top_row_cols = np.nonzero(hit[top, max(0, x0 - 5):x1 + 2])[0] + max(0, x0 - 5)
print("top-row columns x[%d,%d] centroid=%.1f -> %.2f%% of width" % (
    top_row_cols.min(), top_row_cols.max(), top_row_cols.mean(),
    top_row_cols.mean() / W * 100.0))

# 底边是否触底（手臂应出画，不留空白）
print("gun bottom row y=%d (H-1=%d)  touches_bottom=%s" % (
    int(np.nonzero(rows >= 3)[0].max()), H - 1,
    int(np.nonzero(rows >= 3)[0].max()) == H - 1))
