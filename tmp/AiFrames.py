"""AI 像素底板 -> 全部 viewmodel 动画帧。

底图只有一张 idle。其余帧由整数像素变换合成，保证 20 帧同一画风、同一调色板：
  - fire*: 整幅上移（后坐），逐帧递减
  - dry / slide: 整幅上移一点，模拟套筒后座
  - reload*: 整幅下移（换弹时枪下沉）+ 一个程序化弹匣从下方插入
  - draw: 整幅大幅下移（拔枪起始位）

为什么不做旋转：像素画旋转后边缘会出现锯齿和断线，必须保持整数像素平移。

用法: py -3 tmp/AiFrames.py
"""
import os
import numpy as np
from PIL import Image

OUT = r"D:\mygame\assets\sprites\viewmodel"
SRC = r"D:\mygame\tmp\pxout"


def shift(im, dy, dx=0):
    """整数像素平移，保持画布尺寸。"""
    a = np.asarray(im)
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return Image.fromarray(out, "RGBA")


def sample_gun_colors(im):
    """从枪身区域取两档金属色 + 一档黄铜色，给弹匣用。"""
    a = np.asarray(im).astype(np.int32)
    alpha = a[:, :, 3]
    h, w = alpha.shape
    # 枪在左上区域
    sub = a[: h // 2, : int(w * 0.6)]
    m = sub[:, :, 3] > 40
    px = sub[m][:, :3]
    if len(px) == 0:
        return (60, 72, 92), (30, 38, 54), (196, 158, 72)
    lum = (px[:, 0] * 299 + px[:, 1] * 587 + px[:, 2] * 114) // 1000
    dark = px[lum < np.percentile(lum, 25)].mean(axis=0)
    mid = px[(lum > np.percentile(lum, 55)) & (lum < np.percentile(lum, 80))].mean(axis=0)
    return tuple(int(v) for v in mid), tuple(int(v) for v in dark), (196, 158, 72)


def paste_mag(im, top_y, grip_x):
    """在 (grip_x, top_y) 画一个弹匣：深色匣体 + 黄铜底板。"""
    mid, dark, brass = sample_gun_colors(im)
    out = im.copy()
    a = np.asarray(out).copy()
    h, w = a.shape[:2]
    mw, mh = 11, 16
    x0 = max(0, min(w - mw, grip_x))
    y0 = max(0, min(h - mh, top_y))
    # 匣体
    a[y0:y0 + mh, x0:x0 + mw, 0] = dark[0]
    a[y0:y0 + mh, x0:x0 + mw, 1] = dark[1]
    a[y0:y0 + mh, x0:x0 + mw, 2] = dark[2]
    a[y0:y0 + mh, x0:x0 + mw, 3] = 255
    # 左侧受光
    a[y0:y0 + mh, x0:x0 + 2, 0] = mid[0]
    a[y0:y0 + mh, x0:x0 + 2, 1] = mid[1]
    a[y0:y0 + mh, x0:x0 + 2, 2] = mid[2]
    # 黄铜底板
    a[y0 + mh - 3:y0 + mh, x0:x0 + mw, 0] = brass[0]
    a[y0 + mh - 3:y0 + mh, x0:x0 + mw, 1] = brass[1]
    a[y0 + mh - 3:y0 + mh, x0:x0 + mw, 2] = brass[2]
    return Image.fromarray(a, "RGBA")


def build_pistol():
    base = Image.open(os.path.join(SRC, "vm_pistol_idle.png")).convert("RGBA")
    h = base.height
    frames = {
        "idle": base,
        "dry": shift(base, 1, -1),
        "fire1": shift(base, -3, -1),
        "fire2": shift(base, -2, -1),
        "fire3": shift(base, -1, 0),
        "reload1": shift(base, 7),
        "reload2": paste_mag(shift(base, 9), h - 4, 88),
        "reload3": paste_mag(shift(base, 6), h - 12, 88),
        "reload4": shift(base, 2),
        "draw": shift(base, 26),
    }
    for k, v in frames.items():
        v.save(os.path.join(OUT, "vm_pistol_%s.png" % k))
    print("[pistol] %d frames %dx%d" % (len(frames), base.width, base.height))


def build_shotgun():
    base = Image.open(os.path.join(SRC, "vm_shotgun_idle.png")).convert("RGBA")
    frames = {
        "idle": base,
        "fire1": shift(base, -5, -1),
        "fire2": shift(base, -4, -1),
        "fire3": shift(base, -2, 0),
        "fire4": shift(base, -1, 0),
        "fire5": shift(base, -3, 0),
        "reload1": shift(base, 6, 3),
        "reload2": shift(base, 2, 1),
        "draw": shift(base, 24),
        "altfire": shift(base, -2, 0),
    }
    for k, v in frames.items():
        v.save(os.path.join(OUT, "vm_shotgun_%s.png" % k))
    print("[shotgun] %d frames %dx%d" % (len(frames), base.width, base.height))


build_pistol()
build_shotgun()
