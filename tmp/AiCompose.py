"""把 AI 底板重构成「枪身竖直 + 袖口贴底边」的紧凑 viewmodel 贴图。

和 AiAlign.py 的区别（这是关键）：AiAlign 只是整幅旋转，长前臂转过去后会横着
从右边出画，构图仍然错。本文件在旋转后**把长前臂切掉**，只保留到白袖口下缘，
于是袖口正好落在贴图底边 —— 这正是参考帧的构图（前臂在袖口处就出画了，
没有可见的裸前臂段）。

参考帧实测（tmp/fp_png/Handgun__HandgunIdle.png，1100x452）：
  枪身主轴 88.9°（竖直）、前臂走向 -9.5°（几乎竖直向下）、
  opaque 只贴底边（bottom=298，left/right/top 全 0）。

用法: py -3 tmp/AiCompose.py
"""
import os

import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\ai_pistol.png",
       "shotgun": r"D:\mygame\tmp\ai_shotgun.png"}
TARGET_AXIS = {"pistol": 89.0, "shotgun": 89.0}
OUT_H = {"pistol": 128, "shotgun": 128}
COLORS = 22


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
    return op, skin, shirt


def gun_axis(a):
    op, skin, _ = masks(a)
    rgb = a[:, :, :3].astype(np.int32)
    lum = (rgb[:, :, 0] * 299 + rgb[:, :, 1] * 587 + rgb[:, :, 2] * 114) // 1000
    mx = rgb.max(2)
    mn = rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    metal = op & (sat < 70) & (lum >= 55) & (lum <= 215) & ~skin
    ys, xs = np.nonzero(metal)
    if len(xs) < 200:
        return None
    pts = np.stack([xs.astype(np.float64), -ys.astype(np.float64)], axis=1)
    pts -= pts.mean(axis=0)
    w, v = np.linalg.eigh(np.cov(pts.T))
    mj = v[:, np.argmax(w)]
    return np.degrees(np.arctan2(mj[1], mj[0])) % 180.0


def compose(kind):
    im = Image.open(SRC[kind]).convert("RGBA")
    cur = gun_axis(np.asarray(im))
    delta = TARGET_AXIS[kind] - cur
    # 实测：rotate(+a) 让 gun_axis 读数增加 a
    rot = im.rotate(delta, resample=Image.Resampling.BICUBIC, expand=True)
    a = np.asarray(rot)
    print("[%s] axis %.1f -> %.1f (delta %.1f)  rot %dx%d"
          % (kind, cur, gun_axis(a), delta, rot.width, rot.height))

    op, skin, shirt = masks(a)
    ys, xs = np.nonzero(op)
    top = ys.min()
    # 袖口下缘：白袖口像素的最大 y。没有白袖口就退回内容底边。
    if shirt.sum() > 200:
        cuff_bottom = np.nonzero(shirt)[0].max()
    else:
        cuff_bottom = ys.max()
    # 裁切：横向取内容全宽，纵向从枪口顶到袖口下缘（切掉后面的长前臂）
    x0, x1 = xs.min(), xs.max() + 1
    y0, y1 = top, min(cuff_bottom + 1, ys.max() + 1)
    body = rot.crop((x0, y0, x1, y1))
    print("[%s] crop x%d..%d y%d..%d -> %dx%d (arm cut %d px)"
          % (kind, x0, x1, y0, y1, body.width, body.height, ys.max() - y1 + 1))

    oh = OUT_H[kind]
    scale = oh / float(body.height)
    ow = max(1, int(round(body.width * scale)))
    small = body.resize((ow, oh), Image.Resampling.BOX)

    # 量化：剥 alpha 走 RGB 量化，再把 alpha 贴回
    sa = np.asarray(small).copy()
    m = sa[:, :, 3] > 40
    med = np.median(sa[m][:, :3], axis=0).astype(np.uint8)
    sa[~m] = np.array([med[0], med[1], med[2], 255], dtype=np.uint8)
    q = Image.fromarray(sa[:, :, :3], "RGB").quantize(
        colors=COLORS, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")
    qa = np.dstack([np.asarray(q), (m * 255).astype(np.uint8)])
    out = Image.fromarray(qa, "RGBA")

    dst = r"D:\mygame\tmp\pxout\vm_%s_idle.png" % kind
    out.save(dst)
    ys2, xs2 = np.nonzero(qa[:, :, 3] > 40)
    # 枪口位置 = 金属像素最上端的水平中点
    metal = (qa[:, :, 3] > 40)
    my = ys2.min()
    mx_row = xs2[ys2 <= my + 2]
    print("[%s] out %dx%d %dB  cx%%=%.1f  muzzle=(%.1f,%.1f)  bottom=%d/%d"
          % (kind, out.width, out.height, os.path.getsize(dst),
             100.0 * xs2.mean() / out.width, mx_row.mean(), float(my),
             ys2.max(), out.height - 1))


if __name__ == "__main__":
    for k in ("pistol", "shotgun"):
        compose(k)
