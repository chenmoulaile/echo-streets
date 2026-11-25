"""四章实际用到的 27 张材质 —— 现状统计。

输出每张的尺寸、亮度分位、中心 texel（emissive 面锁 UV(0.5,0.5)，中心必须亮）、
以及整组材质的联合调色板规模，用来判断"像素化"要降到多少才既够像素、又不丢材质区分度。

用法: py -3 tmp/MatStats.py
"""
import os
import numpy as np
from PIL import Image

MAT = r"D:\mygame\assets\materials"
NAMES = [
    "BookShelf_Classroom_White", "CeramicFloor_Gray", "CeramicFloor_White",
    "ComputerScreen_BlueScreen", "ConcreteWall", "ExitDoor", "Glass", "Glass_Pane",
    "Locker", "Locker_DarkBlue", "MetalBox_White", "MetalPlateWall", "MetalWall",
    "NormalDoor", "PoolTiles", "SolarPanel", "VendingMachine", "Vent", "WarningLine",
    "WhiteCeiling", "WhiteCeiling_MetalEdge", "WhiteWall", "WhiteWall_Bottom_Blue",
    "WhiteWall_Column", "WhiteWall_Dirty", "WoodenFloor", "YellowWall",
]


def lum(a):
    return (a[:, :, 0].astype(np.int32) * 299 + a[:, :, 1].astype(np.int32) * 587
            + a[:, :, 2].astype(np.int32) * 114) // 1000


print("%-26s %-9s %5s %5s %5s %5s  %-16s %s" % (
    "name", "size", "mean", "p05", "p50", "p95", "center", "alpha"))
allpx = []
for n in NAMES:
    p = os.path.join(MAT, n + ".png")
    if not os.path.exists(p):
        print("%-26s MISSING" % n)
        continue
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im)
    rgb = a[:, :, :3]
    al = a[:, :, 3]
    L = lum(rgb)
    m = al > 40
    if m.sum() == 0:
        m = np.ones_like(al, dtype=bool)
    px = rgb[m].reshape(-1, 3)
    allpx.append(px[::max(1, len(px) // 4000)])
    h, w = L.shape
    cy, cx = h // 2, w // 2
    c = tuple(int(v) for v in rgb[cy, cx])
    print("%-26s %-9s %5.0f %5.0f %5.0f %5.0f  rgb%-14s a=%d" % (
        n, "%dx%d" % (w, h), L[m].mean(),
        np.percentile(L[m], 5), np.percentile(L[m], 50), np.percentile(L[m], 95),
        str(c), al[cy, cx]))

cat = np.concatenate(allpx, axis=0)
print("\n联合像素池 %d px, 唯一色 %d" % (len(cat), len(np.unique(cat.reshape(-1, 3), axis=0))))
