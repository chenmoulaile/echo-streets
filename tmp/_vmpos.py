"""一次性度量：手枪 viewmodel 横向落位候选扫描（纯贴图几何，不碰任何素材）。

用法: python tmp/_vmpos.py
输出: 每个候选 pos.x 的 枪口屏幕 x%、中心区像素质量占比、不透明右边界%。
"""
from PIL import Image
import numpy as np, os

SCR_W, SCR_H = 480, 270
SRC = r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png"
MUZZLE_LOCAL = (48.6, 32.0)
BASE_Y = 82.0
# 中心区（与历史注释同一口径）：x[40%,60%] y[35%,75%]
CX0, CX1 = int(SCR_W * 0.40), int(SCR_W * 0.60)
CY0, CY1 = int(SCR_H * 0.35), int(SCR_H * 0.75)

a = np.asarray(Image.open(SRC).convert("RGBA")).astype(np.int32)
op = a[:, :, 3] > 40          # 不透明 = alpha > 40（与 _vmu8.py 同阈值）
h, w = op.shape
total_op = int(op.sum())

ys, xs = np.nonzero(op)
bx0, bx1, by0, by1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
print("texture %dx%d  opaque bbox x[%d,%d] y[%d,%d]  opaque_px=%d" % (
    w, h, bx0, bx1, by0, by1, total_op))
print("center region  x[%d,%d] y[%d,%d]  area=%d" % (
    CX0, CX1, CY0, CY1, (CX1 - CX0) * (CY1 - CY0)))

region_area = (CX1 - CX0) * (CY1 - CY0)


def measure(posx, posy=BASE_Y):
    # 贴图左上角在 (posx, posy)，只有落在屏幕内的部分参与统计
    ox, oy = int(round(posx)), int(round(posy))
    # 把贴图贴到 480x270 画布上（只取屏内交集）
    canvas = np.zeros((SCR_H, SCR_W), dtype=bool)
    sx0, sy0 = max(0, -ox), max(0, -oy)
    dx0, dy0 = max(0, ox), max(0, oy)
    cw = min(w - sx0, SCR_W - dx0)
    ch = min(h - sy0, SCR_H - dy0)
    if cw > 0 and ch > 0:
        canvas[dy0:dy0 + ch, dx0:dx0 + cw] = op[sy0:sy0 + ch, sx0:sx0 + cw]
    in_region = canvas[CY0:CY1, CX0:CX1]
    center_mass = in_region.sum() / float(region_area)        # 占中心区面积
    center_share = in_region.sum() / float(max(canvas.sum(), 1))  # 占枪身总质量
    muzzle_x = ox + MUZZLE_LOCAL[0]
    right = ox + bx1
    return (muzzle_x / SCR_W * 100.0,
            center_mass * 100.0,
            center_share * 100.0,
            right / SCR_W * 100.0,
            int(in_region.sum()),
            int(canvas.sum()))


CANDS = [206, 216, 222, 228, 234, 240]
print("\npos.x  muzzle%%  center%%(area)  center%%(share)  right%%  region_px  body_px")
rows = []
for c in CANDS:
    r = measure(c)
    rows.append((c,) + r)
    print("%5d  %7.2f  %13.2f  %14.2f  %6.2f  %9d  %7d" % (
        c, r[0], r[1], r[2], r[3], r[4], r[5]))

print("\n-- ADS 候选（左移量 vs 开镜后枪口%）--")
for sx in (-14, -16, -18, -20, -22, -24):
    for base in (222, 228, 234):
        mx = (base + sx + MUZZLE_LOCAL[0]) / SCR_W * 100.0
        print("  base=%3d shift.x=%3d -> ADS pos.x=%3d  ADS muzzle %5.2f%%" % (
            base, sx, base + sx, mx))
