"""AI 生图底板 -> 游戏用像素 viewmodel 帧。

三步：
  1. 按固定窗口裁剪（只留枪 + 手 + 袖口，切掉多余前臂）；
  2. 面积平均降到目标像素尺寸（NEAREST 会丢细节，BOX 平均更像手绘像素）；
  3. k-means 量化到 N 色（全局调色板，所有帧共用一套，避免逐帧跳色）。

输出：assets/sprites/viewmodel/vm_pistol_*.png / vm_shotgun_*.png

用法:
  py -3 tmp/AiPixel.py pistol  <src.png> <outdir>
  py -3 tmp/AiPixel.py shotgun <src.png> <outdir>
"""
import os
import sys
import numpy as np
from PIL import Image

# 裁剪窗口按 1920 基准给出（x0, y0, w, h），会按实际尺寸缩放
CROP = {
    "pistol": (420, 480, 1500, 1440),
    "shotgun": (360, 780, 1560, 1140),
}
# 目标像素尺寸（480x270 逻辑屏上的贴图尺寸）
OUT = {
    "pistol": (132, 126),
    "shotgun": (150, 110),
}
COLORS = 22


def quantize(im, k):
    """全局调色板量化：只用不透明像素做 k-means，透明区保持 0。"""
    a = np.asarray(im).astype(np.float32)
    rgb, alpha = a[:, :, :3], a[:, :, 3]
    mask = alpha > 40
    if mask.sum() == 0:
        return im
    pts = rgb[mask]

    # 用 8 级分箱取初始中心，比随机初始化稳定
    q = (pts // 32).astype(np.int32)
    keys, counts = np.unique(q, axis=0, return_counts=True)
    order = np.argsort(-counts)[:k]
    centers = keys[order].astype(np.float32) * 32.0 + 16.0
    if len(centers) < k:
        pad = np.repeat(centers[-1:], k - len(centers), axis=0)
        centers = np.vstack([centers, pad])

    for _ in range(14):
        d = ((pts[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
        lab = d.argmin(axis=1)
        for i in range(len(centers)):
            sel = lab == i
            if sel.any():
                centers[i] = pts[sel].mean(axis=0)

    d = ((pts[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
    lab = d.argmin(axis=1)
    out_rgb = rgb.copy()
    out_rgb[mask] = centers[lab]
    return Image.fromarray(
        np.dstack([np.clip(out_rgb, 0, 255).astype(np.uint8), alpha.astype(np.uint8)]),
        "RGBA",
    )


def main():
    kind, src, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    im = Image.open(src).convert("RGBA")
    w, h = im.size

    cx, cy, cw, ch = CROP[kind]
    sx, sy = w / 1920.0, h / 1920.0
    box = (int(cx * sx), int(cy * sy), int((cx + cw) * sx), int((cy + ch) * sy))
    cut = im.crop(box)
    print("[%s] src %dx%d crop=%s -> %dx%d" % (kind, w, h, box, cut.width, cut.height))

    tw, th = OUT[kind]
    # 先按目标宽高比裁成同样比例，避免拉伸变形
    tgt_ratio = tw / th
    src_ratio = cut.width / cut.height
    if src_ratio > tgt_ratio:
        nw = int(cut.height * tgt_ratio)
        x_off = (cut.width - nw) // 2
        cut = cut.crop((x_off, 0, x_off + nw, cut.height))
    else:
        nh = int(cut.width / tgt_ratio)
        y_off = (cut.height - nh) // 2
        cut = cut.crop((0, y_off, cut.width, y_off + nh))
    print("     ratio-fit -> %dx%d" % (cut.width, cut.height))

    small = cut.resize((tw, th), Image.BOX)
    small = quantize(small, COLORS)

    os.makedirs(outdir, exist_ok=True)
    dst = os.path.join(outdir, "vm_%s_idle.png" % kind)
    small.save(dst)
    print("     saved %s %dx%d" % (dst, small.width, small.height))


main()
