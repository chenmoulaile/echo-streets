"""把 AI 生成的 viewmodel 底板几何对齐到参考游戏的正确构图。

问题（用户 m08655 实测）：当前底板枪身主轴 117.9°，参考帧是 88.9° —— 差 29°，
而且前臂从右边出画。参考帧前臂只从**底边**出画、枪身水平居中 50%。

做法（顺序不能换）：
1. 在 1920 原始分辨率上旋转到目标主轴角（高分辨率旋转，锯齿在降采样时被面积平均抹掉）
2. 裁到内容 bbox
3. 贴进目标画布：水平居中、内容底边贴画布底边
4. BOX 面积平均降采样到目标尺寸
5. 中位切分量化到 N 色

如果先降采样再旋转，硬边像素块会被插值糊掉 —— 这是本文件存在的原因。

用法: py -3 tmp/AiAlign.py pistol
      py -3 tmp/AiAlign.py shotgun
"""
import os
import sys

import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\ai_pistol.png",
       "shotgun": r"D:\mygame\tmp\ai_shotgun.png"}
# 目标主轴角（参考帧实测：手枪 88.9°、霰弹枪 118.1°）
TARGET_AXIS = {"pistol": 89.0, "shotgun": 118.0}
# 目标输出尺寸（480x270 逻辑屏上的合理占比）
OUT = {"pistol": (132, 126), "shotgun": (150, 110)}
# 内容在画布上的水平中心位置（占宽度比例）。参考帧实测手枪 50.3%、霰弹枪 58.9%。
CENTER_X = {"pistol": 0.50, "shotgun": 0.56}
COLORS = 22


def gun_axis(im):
    """返回金属像素的 PCA 主轴角（度，0~180，y 轴取负即屏幕系）。"""
    a = np.asarray(im.convert("RGBA"))
    rgb = a[:, :, :3].astype(np.int32)
    al = a[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    mx = rgb.max(2)
    mn = rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    # 排除皮肤（暖色高 r-g）与洋红背景
    skin = (r - b > 28) & (r - g > 12)
    metal = (al > 40) & (sat < 70) & (lum >= 55) & (lum <= 215) & ~skin
    ys, xs = np.nonzero(metal)
    if len(xs) < 200:
        return None
    pts = np.stack([xs.astype(np.float64), -ys.astype(np.float64)], axis=1)
    pts -= pts.mean(axis=0)
    w, v = np.linalg.eigh(np.cov(pts.T))
    major = v[:, np.argmax(w)]
    return np.degrees(np.arctan2(major[1], major[0])) % 180.0


def content_bbox(im):
    a = np.asarray(im.convert("RGBA"))
    ys, xs = np.nonzero(a[:, :, 3] > 40)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def align(kind):
    src = SRC[kind]
    im = Image.open(src).convert("RGBA")
    cur = gun_axis(im)
    if cur is None:
        raise SystemExit("no metal pixels in %s" % src)
    delta = TARGET_AXIS[kind] - cur
    print("[%s] src=%s %dx%d  axis=%.1f  target=%.1f  delta=%.1f"
          % (kind, os.path.basename(src), im.width, im.height,
             cur, TARGET_AXIS[kind], delta))
    # 实测符号（不要凭直觉改）：rotate(+a) 让 gun_axis 读数增加 a。
    # 实测 rotate(+28.9) 使 117.9 → 147.0，所以要让读数向目标靠拢就 rotate(delta)。
    rot = im.rotate(delta, resample=Image.Resampling.BICUBIC, expand=True)
    after = gun_axis(rot)
    print("[%s] after rotate axis=%.1f (drift %.2f)" % (kind, after, after - TARGET_AXIS[kind]))

    box = content_bbox(rot)
    body = rot.crop(box)
    ow, oh = OUT[kind]
    # 目标画布按输出宽高比、以内容高度为准定尺寸，再等比缩放到 ow x oh
    scale = oh / float(body.height)
    cw = max(1, int(round(ow / scale)))
    canvas = Image.new("RGBA", (cw, body.height), (0, 0, 0, 0))
    # 水平居中：内容中心落在 cw * CENTER_X 上，且不允许被画布裁掉两侧
    cx_target = cw * CENTER_X[kind]
    px = int(round(cx_target - body.width / 2.0))
    px = max(-(body.width - cw), min(px, cw - 1))
    canvas.paste(body, (px, 0), body)
    # 内容底边贴画布底边（参考帧前臂从底边出画）
    final = canvas.resize((ow, oh), Image.Resampling.BOX)

    # 只用不透明像素做量化，避免透明区主导调色板。
    # RGBA 不能直接 MEDIANCUT 量化（PIL 只允许 FASTOCTREE/LIBIMAGEQUANT），
    # 所以把 alpha 剥离，量化 RGB，再把 alpha 贴回去。
    a = np.asarray(final).copy()
    mask = a[:, :, 3] > 40
    if mask.sum() == 0:
        raise SystemExit("aligned image is fully transparent")
    med = np.median(a[mask][:, :3], axis=0).astype(np.uint8)
    a[~mask] = np.array([med[0], med[1], med[2], 255], dtype=np.uint8)
    q = Image.fromarray(a[:, :, :3], "RGB").quantize(
        colors=COLORS, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")
    qa = np.dstack([np.asarray(q), (mask * 255).astype(np.uint8)])
    out = Image.fromarray(qa, "RGBA")
    dst = r"D:\mygame\tmp\pxout\vm_%s_idle.png" % kind
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    ax = gun_axis(out)
    ys, xs = np.nonzero(qa[:, :, 3] > 40)
    # 量化后金属像素可能不足 200（色阶压缩把中间调并进深/浅两端），
    # 此时 gun_axis 返回 None —— 这是量化的正常副作用，不是失败，
    # 对齐角度应看旋转后的 after rotate 读数。
    axs = "%.1f" % ax if ax is not None else "n/a(<200px)"
    print("[%s] out=%s %dx%d %dB  axis=%s  cx%%=%.1f  bottom=%d/%d  colors=%d"
          % (kind, os.path.basename(dst), out.width, out.height,
             os.path.getsize(dst), axs, 100.0 * xs.mean() / out.width,
             ys.max(), out.height - 1,
             len(np.unique(qa[mask][:, :3].reshape(-1, 3), axis=0))))


if __name__ == "__main__":
    for k in (sys.argv[1:] or ["pistol", "shotgun"]):
        align(k)
