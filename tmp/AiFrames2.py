"""由 AI 底板生成完整 20 帧 viewmodel 动画（伪 3D 像素风格）。

管线（顺序不可换，每步都有实测依据）：
  1. 旋转底板到参考帧枪管角 —— 度量用「枪口相对枪身质心的方向」，不是 PCA
     （PCA 会把深藏青袖子算成金属，手枪读数会从 89° 偏到 118°）。
  2. 裁到「枪口顶 → 白袖口下缘」，切掉后面的长前臂。参考帧前臂在袖口处就出画
     （opaque 只贴底边，left/right/top 全 0）；不切的话前臂会横着从右边出画。
  3. 等比缩放到目标高度，放进固定宽度画布**水平居中并留 3px 边距**，
     否则内容质心偏右（实测手枪 58.1%）会让枪身贴到贴图右边缘被硬切。
  4. 中位切分量化到 22 色（剥 alpha 走 RGB 量化，RGBA 不能 MEDIANCUT）。
  5. 其余动作帧用**整数像素平移**合成 —— 像素画旋转会产生锯齿断线。

用法: py -3 tmp/AiFrames2.py
"""
import os

import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\ai_pistol.png",
       "shotgun": r"D:\mygame\tmp\ai_shotgun.png"}
# 参考帧实测目标枪管角（0 = 竖直朝上，正 = 枪口偏右）；旋转量由扫角得到
DELTA = {"pistol": -70, "shotgun": -15}
OUT_H = {"pistol": 150, "shotgun": 150}
PAD_X = 3
COLORS = 22
DST = r"D:\mygame\assets\sprites\viewmodel"


def masks(a):
    rgb = a[:, :, :3].astype(np.int32)
    al = a[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    mx = rgb.max(2)
    mn = rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    op = al > 40
    skin = op & (r - b > 28) & (r - g > 12) & (lum > 90) & (lum < 235)
    shirt = op & (lum > 200) & (sat < 45)
    navy = op & (lum < 100) & (b > r + 18)
    return op, skin, shirt, navy


def base(kind):
    """返回 (居中后的 idle 图, 枪口坐标, 枪身颜色样本)。"""
    im = Image.open(SRC[kind]).convert("RGBA")
    rot = im.rotate(DELTA[kind], resample=Image.Resampling.BICUBIC, expand=True)
    a = np.asarray(rot)
    op, skin, shirt, navy = masks(a)
    ys, xs = np.nonzero(op)
    top = ys.min()
    cuff = np.nonzero(shirt)[0].max() if shirt.sum() > 200 else ys.max()
    body = rot.crop((xs.min(), top, xs.max() + 1, min(cuff + 1, ys.max() + 1)))

    oh = OUT_H[kind]
    scale = oh / float(body.height)
    bw = max(1, int(round(body.width * scale)))
    small = body.resize((bw, oh), Image.Resampling.BOX)

    # 固定宽度画布 + 水平居中 + 留边距：内容质心偏右时不会被贴图右缘硬切
    canvas_w = bw + PAD_X * 2
    canvas = Image.new("RGBA", (canvas_w, oh), (0, 0, 0, 0))
    canvas.paste(small, (PAD_X, 0), small)

    sa = np.asarray(canvas).copy()
    m = sa[:, :, 3] > 40
    med = np.median(sa[m][:, :3], axis=0).astype(np.uint8)
    sa[~m] = np.array([med[0], med[1], med[2], 255], dtype=np.uint8)
    q = Image.fromarray(sa[:, :, :3], "RGB").quantize(
        colors=COLORS, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")
    qa = np.dstack([np.asarray(q), (m * 255).astype(np.uint8)])
    out = Image.fromarray(qa, "RGBA")

    ys2, xs2 = np.nonzero(qa[:, :, 3] > 40)
    my = int(ys2.min())
    mx = float(xs2[ys2 <= my + 2].mean())
    return out, (mx, float(my))


def shift(im, dy, dx=0):
    """整数像素平移，保持画布尺寸（超出部分裁掉，不重采样）。"""
    a = np.asarray(im)
    h, w = a.shape[:2]
    out = np.zeros_like(a)
    sy0, sy1 = max(0, -dy), min(h, h - dy)
    sx0, sx1 = max(0, -dx), min(w, w - dx)
    if sy0 < sy1 and sx0 < sx1:
        out[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx] = a[sy0:sy1, sx0:sx1]
    return Image.fromarray(out, "RGBA")


def gun_colors(im):
    """从枪身左上区域取中调 / 暗调 / 黄铜三色，供程序化弹匣使用。"""
    a = np.asarray(im)
    rgb = a[:, :, :3].astype(np.int32)
    al = a[:, :, 3]
    lum = (rgb[:, :, 0] * 299 + rgb[:, :, 1] * 587 + rgb[:, :, 2] * 114) // 1000
    h, w = lum.shape
    region = (al > 200) & (lum > 30) & (lum < 190)
    region[: h // 3] = False
    region[:, : w // 3] = False
    vals = lum[region]
    if len(vals) < 40:
        return (60, 66, 84), (34, 38, 50), (216, 174, 86)
    lo, hi = np.percentile(vals, 35), np.percentile(vals, 70)
    mid_m = region & (lum >= hi - 6) & (lum <= hi + 6)
    dark_m = region & (lum >= lo - 6) & (lum <= lo + 6)
    mid = tuple(int(v) for v in rgb[mid_m].mean(axis=0)) if mid_m.sum() else (60, 66, 84)
    dark = tuple(int(v) for v in rgb[dark_m].mean(axis=0)) if dark_m.sum() else (34, 38, 50)
    return mid, dark, (216, 174, 86)


def paste_mag(im, top_y, grip_x, mid, dark, brass):
    """在握把下方画一个 11x16 的弹匣：匣体 + 左侧 2px 受光 + 底部 3px 黄铜底板。"""
    a = np.asarray(im).copy()
    h, w = a.shape[:2]
    for y in range(top_y, min(top_y + 16, h)):
        for x in range(grip_x, min(grip_x + 11, w)):
            col = mid if x < grip_x + 2 else dark
            a[y, x] = (col[0], col[1], col[2], 255)
    for y in range(min(top_y + 13, h), min(top_y + 16, h)):
        for x in range(grip_x, min(grip_x + 11, w)):
            a[y, x] = (brass[0], brass[1], brass[2], 255)
    return Image.fromarray(a, "RGBA")


def build(kind):
    idle, muzzle = base(kind)
    w, h = idle.size
    mid, dark, brass = gun_colors(idle)
    print("[%s] idle %dx%d muzzle=(%.1f,%.1f) palette mid=%s dark=%s"
          % (kind, w, h, muzzle[0], muzzle[1], mid, dark))

    frames = {}
    if kind == "pistol":
        frames["idle"] = idle
        frames["dry"] = shift(idle, 1, -1)
        frames["fire1"] = shift(idle, -3, -1)
        frames["fire2"] = shift(idle, -2, -1)
        frames["fire3"] = shift(idle, -1, 0)
        frames["reload1"] = shift(idle, 7)
        frames["reload2"] = paste_mag(shift(idle, 9), h - 4, w - 44, mid, dark, brass)
        frames["reload3"] = paste_mag(shift(idle, 6), h - 12, w - 44, mid, dark, brass)
        frames["reload4"] = shift(idle, 2)
        frames["draw"] = shift(idle, 26)
    else:
        frames["idle"] = idle
        frames["fire1"] = shift(idle, -5, -1)
        frames["fire2"] = shift(idle, -4, -1)
        frames["fire3"] = shift(idle, -2, 0)
        frames["fire4"] = shift(idle, -1, 0)
        frames["fire5"] = shift(idle, -3, 0)
        frames["reload1"] = shift(idle, 6, 3)
        frames["reload2"] = shift(idle, 2, 1)
        frames["draw"] = shift(idle, 24)
        frames["altfire"] = shift(idle, -2, 0)

    total = 0
    for name, im in frames.items():
        p = os.path.join(DST, "vm_%s_%s.png" % (kind, name))
        im.save(p)
        total += os.path.getsize(p)
    print("[%s] wrote %d frames, %d bytes total, size %dx%d"
          % (kind, len(frames), total, w, h))
    return w, h, muzzle


if __name__ == "__main__":
    for k in ("pistol", "shotgun"):
        build(k)
