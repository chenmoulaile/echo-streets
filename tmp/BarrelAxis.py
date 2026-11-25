r"""用「枪口尖端 → 白袖口质心」连线度量枪管朝向（取代旧的口径）。

旧口径（枪口 x 均值 vs 全体质心）有系统性偏差：质心被手部大面积像素拉到右下，
算出的角度比目视结果偏正约 38 度，于是把参考帧误读成「枪管竖直略偏右」，
再据此把新图强制成竖直 —— 这正是用户说「枪管朝天花板」的根因。

新口径用两个语义明确的锚点：
  muzzle  = gun 掩码最上端 5 行的 x 均值
  cuff    = shirt（白袖口）掩码质心
朝向角 = atan2(muzzle_x - cuff_x, cuff_y - muzzle_y)，单位度；
        0 = 竖直向上，负 = 向左偏，正 = 向右偏。

用法: py -3 tmp/BarrelAxis.py
"""
import glob
import os

import numpy as np
from PIL import Image


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
    return gun, shirt, skin, navy


def barrel_deg(a):
    gun, shirt, skin, navy = masks(a)
    if gun.sum() < 30 or shirt.sum() < 30:
        return None
    ys, xs = np.nonzero(gun)
    top = ys.min()
    muzzle_x = xs[ys <= top + 4].mean()
    sy, sx = np.nonzero(shirt)
    cuff_x, cuff_y = sx.mean(), sy.mean()
    up = cuff_y - top
    left = muzzle_x - cuff_x
    return float(np.degrees(np.arctan2(left, up))), int(gun.sum()), (muzzle_x, float(top)), (cuff_x, cuff_y)


def report(path, tag):
    a = np.asarray(Image.open(path).convert("RGBA"))
    r = barrel_deg(a)
    if not r:
        print("%-46s %s" % (os.path.basename(path)[:46], "insufficient masks"))
        return
    deg, n, mz, cf = r
    print("%-46s barrel=%+7.1f deg  gun_px=%5d  muzzle=(%.1f,%.1f)  cuff=(%.1f,%.1f)"
          % (os.path.basename(path)[:46], deg, n, mz[0], mz[1], cf[0], cf[1]))


print("=== 参考帧（用户认可的视角）===")
for f in sorted(glob.glob(r"D:\mygame\tmp\fp_png\*Handgun*Idle*.png")) + \
         sorted(glob.glob(r"D:\mygame\tmp\fp_png\*Shotgun*Idle*.png")):
    report(f, "ref")

print()
print("=== 当前落地帧 ===")
for f in (r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png",
          r"D:\mygame\assets\sprites\viewmodel\vm_shotgun_idle.png"):
    report(f, "cur")

print()
print("=== AI 底板（未旋转）===")
for f in (r"D:\mygame\tmp\ai_pistol.png", r"D:\mygame\tmp\ai_shotgun.png"):
    if os.path.exists(f):
        report(f, "src")
