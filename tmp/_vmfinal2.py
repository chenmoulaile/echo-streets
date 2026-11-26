"""复核 2：只在枪身连通块（含 x=300 的那一段）内量枪口与左右边界，
排除左侧丧尸的同色像素干扰。"""
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
# 枪身列块 = 包含 x=300 的连续段（列命中数 >= 3）
def run_containing(xmid, thresh=3):
    ok = cols >= thresh
    if not ok[xmid]:
        return None
    a = xmid
    while a - 1 >= 0 and ok[a - 1]:
        a -= 1
    b = xmid
    while b + 1 < W and ok[b + 1]:
        b += 1
    return a, b

a, b = run_containing(300)
print("gun body column run x[%d,%d]  left=%.1f%%  right=%.2f%% (predicted 266..406 => 55.4%%..84.6%%)"
      % (a, b, a / W * 100.0, b / W * 100.0))

sub = hit[:, a:b + 1]
rows = sub.sum(axis=1)
top = int(np.nonzero(rows >= 3)[0].min())
bot = int(np.nonzero(rows >= 3)[0].max())
print("gun rows y[%d,%d]  (predicted top 114, bottom 269)" % (top, bot))

topcols = np.nonzero(hit[top, a:b + 1])[0] + a
print("muzzle (top row) x[%d,%d] centroid=%.1f -> %.2f%% (predicted 57.6%%)"
      % (topcols.min(), topcols.max(), topcols.mean(), topcols.mean() / W * 100.0))

# 中心区占用（全屏统计，含背景，仅作图像侧对照）
CX0, CX1, CY0, CY1 = 192, 288, 94, 202
reg = hit[CY0:CY1, CX0:CX1]
print("screenshot center-region gun-pixel share of region = %.2f%% (texture-predicted 11.27%%)"
      % (reg.sum() / float((CX1 - CX0) * (CY1 - CY0)) * 100.0))
