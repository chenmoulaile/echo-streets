"""把四章材质批量转成伪 3D 像素风。

三个动作，缺一不可：
1. BOX 面积平均降采样到 1/N —— 200x200 的摄影纹理在 480x270 的渲染分辨率下，
   每个 texel 远小于一个屏幕像素，mipmap 只会把它糊成灰雾。降到 1/N 让 texel
   变成看得见的方块，这才是"像素"的来源。
2. 只在 alpha>40 的像素上做调色板量化 —— 透明边缘的 RGB 是垃圾值，参与量化
   会把调色板拉黑。
3. NEAREST 回放到原尺寸 —— 保持文件尺寸与 .import 设置不变，让 2x2 或 3x3
   的硬边方块直接由 NEAREST 采样出来，不产生任何插值过渡。

alpha 通道也一起降采样（同样 BOX + NEAREST 回放），否则玻璃的软边会保留
抗锯齿过渡，和硬边像素冲突。

用法:
  py -3 tmp/MatPixel.py --scale 2 --colors 8          # 预演，打印统计
  py -3 tmp/MatPixel.py --scale 2 --colors 8 --apply   # 落盘
"""
import argparse
import os
import shutil

import numpy as np
from PIL import Image

MAT = r"D:\mygame\assets\materials"
BACKUP = r"D:\mygame\tmp\mat_orig"
NAMES = [
    "BookShelf_Classroom_White", "CeramicFloor_Gray", "CeramicFloor_White",
    "ComputerScreen_BlueScreen", "ConcreteWall", "ExitDoor", "Glass", "Glass_Pane",
    "Locker", "Locker_DarkBlue", "MetalBox_White", "MetalPlateWall", "MetalWall",
    "NormalDoor", "PoolTiles", "SolarPanel", "VendingMachine", "Vent", "WarningLine",
    "WhiteCeiling", "WhiteCeiling_MetalEdge", "WhiteWall", "WhiteWall_Bottom_Blue",
    "WhiteWall_Column", "WhiteWall_Dirty", "WoodenFloor", "YellowWall",
]


def quantize(rgb, mask, k):
    """中位切分量化。只用 mask 内的像素定调色板，再用最近色回填整幅。"""
    src = Image.fromarray(rgb, "RGB")
    px = rgb[mask].reshape(-1, 3)
    if len(px) == 0:
        return rgb, 0
    # 把 mask 外像素临时替换成 mask 均值，避免它们主导调色板
    work = rgb.copy()
    if not mask.all():
        work[~mask] = np.median(px, axis=0).astype(np.uint8)
    pal_im = Image.fromarray(work, "RGB").quantize(
        colors=k, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = np.asarray(pal_im.convert("RGB"))
    return out, len(np.unique(out[mask].reshape(-1, 3), axis=0))


def process(name, scale, k, apply):
    p = os.path.join(MAT, name + ".png")
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGBA")
    w, h = im.size
    a = np.asarray(im)
    rgb = a[:, :, :3].copy()
    al = a[:, :, 3]
    mask = al > 40
    if mask.sum() == 0:
        mask = np.ones_like(al, dtype=bool)
    before = len(np.unique(rgb[mask].reshape(-1, 3), axis=0))

    # 1. 降采样
    sw, sh = max(1, w // scale), max(1, h // scale)
    small = im.resize((sw, sh), Image.BOX)
    sa = np.asarray(small)
    s_rgb, s_al = sa[:, :, :3].copy(), sa[:, :, 3]
    s_mask = s_al > 40
    if s_mask.sum() == 0:
        s_mask = np.ones_like(s_al, dtype=bool)

    # 2. 量化
    q_rgb, after = quantize(s_rgb, s_mask, k)

    # 3. 回放到原尺寸（NEAREST，产生 scale x scale 硬边方块）
    merged = np.dstack([q_rgb, s_al])
    big = Image.fromarray(merged, "RGBA").resize((w, h), Image.NEAREST)
    out = np.asarray(big).copy()
    # alpha 半透明的像素其 RGB 保持量化结果即可；全透明像素归零，省得描边发黑
    out[out[:, :, 3] == 0] = (0, 0, 0, 0)

    if apply:
        if not os.path.exists(os.path.join(BACKUP, name + ".png")):
            os.makedirs(BACKUP, exist_ok=True)
            shutil.copy2(p, os.path.join(BACKUP, name + ".png"))
        Image.fromarray(out, "RGBA").save(p, optimize=True)

    return (name, "%dx%d" % (w, h), before, after, int(mask.sum()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", type=int, default=2)
    ap.add_argument("--colors", type=int, default=8)
    ap.add_argument("--apply", action="store_true")
    ns = ap.parse_args()

    print("scale=%d colors=%d apply=%s" % (ns.scale, ns.colors, ns.apply))
    print("%-26s %-9s %6s %6s %7s" % ("name", "size", "before", "after", "opaque"))
    tot_b = tot_a = 0
    for n in NAMES:
        r = process(n, ns.scale, ns.colors, ns.apply)
        if r is None:
            print("%-26s MISSING" % n)
            continue
        tot_b += r[2]
        tot_a += r[3]
        print("%-26s %-9s %6d %6d %7d" % r)
    print("\n唯一色合计 %d -> %d (%.1f%%)" % (
        tot_b, tot_a, 100.0 * tot_a / max(1, tot_b)))


if __name__ == "__main__":
    main()
