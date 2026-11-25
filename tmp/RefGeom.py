"""量化参考游戏 FirstPerson 帧的构图 —— 用户认可的"视角正确"基线。

要回答三个问题：
1. 枪身主轴在屏幕上的角度是多少（从握把指向枪口的向量角）。
2. 手（皮肤色）落在画面哪个区域。
3. 前臂从哪条边出画。

做法：按色相/亮度把像素分成「金属枪身」「皮肤」「白袖口」「深色衣物」四类，
对金属类做 PCA 求主轴角度，再分别打印各类的 bbox 与质心。

用法: py -3 tmp/RefGeom.py
"""
import glob
import os

import numpy as np
from PIL import Image

SRC = r"D:\mygame\tmp\fp_png"


def classify(a):
    """返回四个布尔掩码：metal / skin / shirt / dark。"""
    rgb = a[:, :, :3].astype(np.int32)
    al = a[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    lum = (r * 299 + g * 587 + b * 114) // 1000
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    opaque = al > 40
    # 皮肤：偏红偏暖，r 明显大于 b，中等亮度
    skin = opaque & (r - b > 28) & (r - g > 12) & (lum > 90) & (lum < 235) & (sat < 110)
    # 白袖口：高亮低饱和
    shirt = opaque & (lum > 205) & (sat < 40)
    # 金属枪身：低饱和中高亮
    metal = opaque & (sat < 60) & (lum >= 60) & (lum <= 205) & ~skin
    # 深色衣物
    dark = opaque & (lum < 60)
    return metal, skin, shirt, dark


def pca_angle(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) < 50:
        return None
    pts = np.stack([xs.astype(np.float64), -ys.astype(np.float64)], axis=1)
    pts -= pts.mean(axis=0)
    cov = np.cov(pts.T)
    w, v = np.linalg.eigh(cov)
    major = v[:, np.argmax(w)]
    ang = np.degrees(np.arctan2(major[1], major[0]))
    return ang % 180.0, len(xs)


def edge_exit(mask):
    """统计不透明像素贴到哪几条边，判断前臂出画方向。"""
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return {}
    h, w = mask.shape
    return {
        "left": int((xs <= 1).sum()), "right": int((xs >= w - 2).sum()),
        "top": int((ys <= 1).sum()), "bottom": int((ys >= h - 2).sum()),
    }


files = sorted(glob.glob(os.path.join(SRC, "*Handgun*.png")))[:6]
files += sorted(glob.glob(os.path.join(SRC, "*Shotgun*.png")))[:3]
print("%-34s %-9s %-13s %-22s %s" % ("file", "size", "gun-axis", "hand bbox", "exit edges"))
for f in files:
    im = Image.open(f).convert("RGBA")
    a = np.asarray(im)
    w, h = im.size
    metal, skin, shirt, dark = classify(a)
    ga = pca_angle(metal)
    ys, xs = np.nonzero(skin)
    hb = "x%d..%d y%d..%d" % (xs.min(), xs.max(), ys.min(), ys.max()) if len(xs) else "none"
    ex = edge_exit(a[:, :, 3] > 40)
    exs = ",".join("%s=%d" % (k, v) for k, v in ex.items() if v > 3)
    print("%-34s %-9s %-13s %-22s %s" % (
        os.path.basename(f)[:34], "%dx%d" % (w, h),
        ("%.1f deg n=%d" % ga) if ga else "none", hb, exs))
