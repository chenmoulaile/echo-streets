"""把 AI 底板旋转到「枪管竖直朝上」的参考构图，切掉长前臂，输出紧凑 viewmodel 贴图。

为什么需要本文件（前两次都失败的根因）：
  1. AiAlign.py 用金属色做 PCA 求主轴 —— 深藏青袖子也是低饱和蓝灰，被算进金属，
     读数 117.9° 是「枪 + 袖子」的合成方向，不是枪管方向。
  2. 正确度量是**几何**的：枪口（内容最上端像素）相对枪身质心的偏移向量，
     与竖直方向的夹角。参考帧 HandgunIdle 实测 +10.5°（几乎竖直、枪口略偏右），
     霰弹枪 ShotgunIdle 实测 -31.1°（明显向左上）。
  3. 只旋转不切前臂，长前臂会横着从右边出画 —— 参考帧前臂在袖口处就出画了
     （opaque 只贴底边：bottom=298，left/right/top 全 0）。

用法: py -3 tmp/AiCompose2.py            # 自动扫角并输出两张 idle
      py -3 tmp/AiCompose2.py --sweep    # 只打印角度扫描表，不写文件
"""
import os
import sys

import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\ai_pistol.png",
       "shotgun": r"D:\mygame\tmp\ai_shotgun.png"}
# 参考帧实测目标枪管角（0 = 竖直朝上，正 = 枪口偏右）
TARGET_BARREL = {"pistol": 10.5, "shotgun": -31.1}
OUT_H = {"pistol": 152, "shotgun": 152}
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
    # 深藏青外套袖子：暗且明显偏蓝。必须排除，否则它会把"枪"的质心拉偏。
    navy = op & (lum < 100) & (b > r + 18)
    gun = op & ~skin & ~shirt & ~navy
    return op, skin, shirt, navy, gun


def barrel_deg(a):
    """枪管相对竖直的偏角：枪口（内容最上端）相对枪身质心的方向。0=竖直朝上。"""
    op, skin, shirt, navy, gun = masks(a)
    ys, xs = np.nonzero(gun)
    if len(xs) < 300:
        return None
    cx, cy = xs.mean(), ys.mean()
    my = ys.min()
    top = xs[ys <= my + 3]
    return np.degrees(np.arctan2(top.mean() - cx, cy - my))


def sweep(kind):
    im = Image.open(SRC[kind]).convert("RGBA")
    base = barrel_deg(np.asarray(im))
    print("[%s] base barrel=%.1f target=%.1f" % (kind, base, TARGET_BARREL[kind]))
    best = None
    for d in range(-80, 81, 5):
        r = im.rotate(d, resample=Image.Resampling.BICUBIC, expand=True)
        b = barrel_deg(np.asarray(r))
        if b is None:
            continue
        err = abs(b - TARGET_BARREL[kind])
        print("   delta %+4d -> barrel %+7.1f  err %5.1f" % (d, b, err))
        if best is None or err < best[0]:
            best = (err, d, b)
    print("[%s] best delta=%+d (barrel %.1f, err %.1f)" % (kind, best[1], best[2], best[0]))
    return best[1]


def compose(kind, delta):
    im = Image.open(SRC[kind]).convert("RGBA")
    rot = im.rotate(delta, resample=Image.Resampling.BICUBIC, expand=True)
    a = np.asarray(rot)
    op, skin, shirt, navy, gun = masks(a)
    ys, xs = np.nonzero(op)
    top = ys.min()
    # 袖口下缘 = 白袖口像素的最大 y；没有白袖口就退回内容底边
    cuff = np.nonzero(shirt)[0].max() if shirt.sum() > 200 else ys.max()
    x0, x1 = xs.min(), xs.max() + 1
    y0, y1 = top, min(cuff + 1, ys.max() + 1)
    body = rot.crop((x0, y0, x1, y1))
    print("[%s] delta=%+d barrel=%.1f  rot %dx%d  crop x%d..%d y%d..%d = %dx%d (cut %d px arm)"
          % (kind, delta, barrel_deg(a), rot.width, rot.height,
             x0, x1, y0, y1, body.width, body.height, ys.max() - y1 + 1))

    oh = OUT_H[kind]
    scale = oh / float(body.height)
    ow = max(1, int(round(body.width * scale)))
    small = body.resize((ow, oh), Image.Resampling.BOX)

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
    my = ys2.min()
    mx = xs2[ys2 <= my + 2].mean()
    print("[%s] out %dx%d %dB  cx%%=%.1f  muzzle=(%.1f,%.1f)  bottom=%d/%d"
          % (kind, out.width, out.height, os.path.getsize(dst),
             100.0 * xs2.mean() / out.width, mx, float(my),
             ys2.max(), out.height - 1))


if __name__ == "__main__":
    only_sweep = "--sweep" in sys.argv
    for k in ("pistol", "shotgun"):
        d = sweep(k)
        if not only_sweep:
            compose(k, d)
