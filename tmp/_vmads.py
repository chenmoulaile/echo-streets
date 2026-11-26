"""ADS 候选细算：开镜后（pos.x + ADS_SHIFT.x）的中心区占用，供选 ADS_SHIFT.x 用。"""
from PIL import Image
import numpy as np

SCR_W, SCR_H = 480, 270
SRC = r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png"
op = np.asarray(Image.open(SRC).convert("RGBA"))[:, :, 3] > 40
h, w = op.shape
CX0, CX1 = int(SCR_W * 0.40), int(SCR_W * 0.60)
CY0, CY1 = int(SCR_H * 0.35), int(SCR_H * 0.75)
area = (CX1 - CX0) * (CY1 - CY0)


def measure(posx, posy=82):
    ox, oy = int(posx), int(posy)
    canvas = np.zeros((SCR_H, SCR_W), dtype=bool)
    sx0, sy0 = max(0, -ox), max(0, -oy)
    dx0, dy0 = max(0, ox), max(0, oy)
    cw = min(w - sx0, SCR_W - dx0)
    ch = min(h - sy0, SCR_H - dy0)
    canvas[dy0:dy0 + ch, dx0:dx0 + cw] = op[sy0:sy0 + ch, sx0:sx0 + cw]
    reg = canvas[CY0:CY1, CX0:CX1].sum()
    return reg / area * 100.0, (ox + 178) / SCR_W * 100.0


print("ADS pos.x  muzzle%%  center%%")
for p in (192, 198, 200, 202, 204, 208, 214):
    c, r = measure(p)
    print("%9d  %7.2f  %7.2f" % (p, (p + 48.6) / SCR_W * 100.0, c))
