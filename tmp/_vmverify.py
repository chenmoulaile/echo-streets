"""截图侧复核：在 01_idle.png 上实测枪身不透明区右边界与枪口横向位置，
与贴图几何预测（pos.x=228 → 右边界 84.6%、枪口 57.6%）对照。"""
from PIL import Image
import numpy as np

im = np.asarray(Image.open(r"D:\mygame\tmp\shots\01_idle.png").convert("RGB")).astype(np.int32)
H, W, _ = im.shape

# 枪身/手：贴图的不透明像素来自 vm_pistol_idle.png，取其 alpha>40 的颜色集合，
# 在截图里找这些颜色的像素（容差 0，因为 NEAREST + 无混合，颜色应逐位相同）。
src = np.asarray(Image.open(
    r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png").convert("RGBA"))
mask = src[:, :, 3] > 40
cols = src[:, :, :3][mask]
uniq = np.unique(cols.reshape(-1, 3), axis=0)
print("texture distinct opaque colors:", len(uniq))

hit = np.zeros((H, W), dtype=bool)
for c in uniq:
    hit |= np.all(im == c, axis=2)
ys, xs = np.nonzero(hit)
print("matched px:", hit.sum())
if hit.sum():
    print("screenshot gun bbox x[%d,%d] y[%d,%d]" % (xs.min(), xs.max(), ys.min(), ys.max()))
    print("right edge = %.2f%% of width" % (xs.max() / W * 100.0))
    # 枪口：贴图内 (48.6,32) → 对应贴图 x=49 列的最上方像素，量它的屏幕位置
    mz_world_x = xs.min() + (49 - 38)  # 贴图不透明 bbox 左界 38 → 贴图内 49 列
    print("muzzle col approx = %d  (%.2f%%)" % (mz_world_x, mz_world_x / W * 100.0))
