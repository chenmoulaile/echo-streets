"""副作用核查：ADS_SHIFT.x 由 -14 改为 -20 后，霰弹枪开镜落位是否仍合理。

霰弹枪 pos=(158,120)、贴图 259x150、muzzle=(93.9,0)。ADS 后 pos.x = 158 + shift.x。
"""
from PIL import Image
import numpy as np

SCR_W, SCR_H = 480, 270
op = np.asarray(Image.open(
    r"D:\mygame\assets\sprites\viewmodel\vm_shotgun_idle.png").convert("RGBA"))[:, :, 3] > 40
h, w = op.shape
CX0, CX1 = int(SCR_W * 0.40), int(SCR_W * 0.60)
CY0, CY1 = int(SCR_H * 0.35), int(SCR_H * 0.75)
area = (CX1 - CX0) * (CY1 - CY0)
ys, xs = np.nonzero(op)
bx1 = int(xs.max())


def measure(posx, posy):
    ox, oy = int(posx), int(posy)
    canvas = np.zeros((SCR_H, SCR_W), dtype=bool)
    sx0, sy0 = max(0, -ox), max(0, -oy)
    dx0, dy0 = max(0, ox), max(0, oy)
    cw = min(w - sx0, SCR_W - dx0)
    ch = min(h - sy0, SCR_H - dy0)
    canvas[dy0:dy0 + ch, dx0:dx0 + cw] = op[sy0:sy0 + ch, sx0:sx0 + cw]
    return canvas[CY0:CY1, CX0:CX1].sum() / area * 100.0, (ox + bx1) / SCR_W * 100.0


print("shotgun  pos.x  muzzle%%  center%%  right%%")
for label, px in (("hop 158 (腰射)", 158), ("ads@-14  144", 144), ("ads@-20  138", 138)):
    c, r = measure(px, 120)
    print("%-16s %4d  %7.2f  %7.2f  %6.2f" % (label, px, (px + 93.9) / SCR_W * 100.0, c, r))
