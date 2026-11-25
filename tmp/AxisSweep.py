r"""扫描最佳旋转角，使 AI 底板的枪管朝向匹配参考帧。

新度量（tmp/BarrelAxis.py 的 barrel_deg）：以「枪口尖端」与「白袖口质心」为锚点，
0 = 竖直向上，负 = 向左偏。参考帧实测手枪 -22.0、霰弹枪 -17.8。

旧度量（枪口 x 均值 vs 全体质心）被手部像素拉偏，把参考帧误读成 +10.5，
于是旋转了 -70 度，把本来正确的「枪管朝左上」转成了「枪管朝天花板」。

用法: py -3 tmp/AxisSweep.py
"""
import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\ai_pistol.png",
       "shotgun": r"D:\mygame\tmp\ai_shotgun.png"}
TARGET = {"pistol": -22.0, "shotgun": -17.8}


def masks(a):
    rgb = a[:, :, :3].astype(np.int32)
    al = a[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    lum = (r * 299 + g * 587 + b * 114) // 1000
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    op = al > 40
    skin = op & (r - b > 28) & (r - g > 12) & (lum > 90) & (lum < 235) & (sat < 110)
    shirt = op & (lum > 200) & (sat < 45)
    navy = op & (lum < 100) & (b > r + 18)
    gun = op & ~skin & ~shirt & ~navy
    return gun, shirt, skin, navy, op


def measure(im):
    a = np.asarray(im.convert("RGBA"))
    gun, shirt, skin, navy, op = masks(a)
    if gun.sum() < 40 or shirt.sum() < 40:
        return None
    ys, xs = np.nonzero(gun)
    top = ys.min()
    muzzle_x = xs[ys <= top + 4].mean()
    sy, sx = np.nonzero(shirt)
    deg = float(np.degrees(np.arctan2(muzzle_x - sx.mean(), sy.mean() - top)))
    gw = xs.max() - xs.min() + 1
    gh = ys.max() - ys.min() + 1
    return deg, gh / max(gw, 1), gw, gh


for kind, path in SRC.items():
    im = Image.open(path).convert("RGBA")
    bb = im.split()[3].getbbox()
    im = im.crop(bb)
    m0 = measure(im)
    print("[%s] src barrel=%+.1f aspect=%.2f (%dx%d) target=%+.1f"
          % (kind, m0[0], m0[1], m0[2], m0[3], TARGET[kind]))
    best = None
    for d in range(-40, 61, 2):
        rot = im.rotate(d, resample=Image.BICUBIC, expand=True)
        m = measure(rot)
        if not m:
            continue
        err = abs(m[0] - TARGET[kind])
        if best is None or err < best[1]:
            best = (d, err, m[0], m[1])
    print("   best delta=%+d  barrel=%+.1f  err=%.1f  aspect=%.2f" % best)
