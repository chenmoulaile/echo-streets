r"""把 tmp/VmRebuild.py 产出的母图派生成完整 viewmodel 动画帧。

母图是 tmp/rb_pistol.png / tmp/rb_shotgun.png（245x262 / 464x275），
保留了参考帧的**透视压缩**（枪管指向屏幕深处，看到套筒顶面与背面）。
之前走错的路：把 AI 侧视剖面旋转 70 度硬凑成「枪管竖直」——侧视图没有顶面，
旋转只能得到一张转来转去的侧视图，于是枪管看起来「朝天花板」。

派生原则（像素画铁律）：**只做整数像素平移，绝不旋转**。
像素画旋转会产生锯齿断线与抗锯齿灰边，一帧就毁掉整体质感。

用法: py -3 tmp/VmFrames3.py
"""
import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\rb_pistol.png",
       "shotgun": r"D:\mygame\tmp\rb_shotgun.png"}
DST = r"D:\mygame\assets\sprites\viewmodel"
OUT_H = {"pistol": 150, "shotgun": 150}
PAD_X = 3
COLORS = 24


def quantize(im):
    """RGBA 不能用 MEDIANCUT，必须剥 alpha 走 RGB 量化再贴回。"""
    alpha = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT,
                                     dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def base(kind):
    im = Image.open(SRC[kind]).convert("RGBA")
    im = im.crop(im.split()[3].getbbox())
    h = OUT_H[kind]
    w = max(1, int(round(im.width * h / im.height)))
    im = im.resize((w, h), Image.BOX)
    # 左右各留 PAD_X，避免枪身被贴图边缘硬切
    canvas = Image.new("RGBA", (w + PAD_X * 2, h), (0, 0, 0, 0))
    canvas.alpha_composite(im, (PAD_X, 0))
    canvas = quantize(canvas)
    a = np.asarray(canvas)
    alpha = a[:, :, 3] > 40
    ys, xs = np.nonzero(alpha)
    top = ys.min()
    muzzle_x = float(xs[ys <= top + 3].mean())
    return canvas, (muzzle_x, float(top))


def shift(im, dy, dx=0):
    """整数像素平移，保持画布尺寸（移出部分被裁掉，空出的地方保持透明）。"""
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.alpha_composite(im, (dx, dy))
    return out


def gun_colors(im):
    """从枪身左上区域按亮度分位取中间调与暗调，用于程序化弹匣。"""
    a = np.asarray(im).astype(np.int32)
    h, w = a.shape[:2]
    reg = a[: int(h * 0.5), : int(w * 0.5)]
    op = reg[:, :, 3] > 40
    if not op.any():
        return (60, 70, 90), (30, 36, 50)
    px = reg[op][:, :3]
    lum = (px[:, 0] * 299 + px[:, 1] * 587 + px[:, 2] * 114) // 1000
    mid = px[np.argsort(lum)[int(len(lum) * 0.70)]]
    dark = px[np.argsort(lum)[int(len(lum) * 0.35)]]
    return tuple(int(v) for v in mid), tuple(int(v) for v in dark)


def paste_mag(im, top_y, grip_x, mid, dark, brass=(216, 174, 86)):
    """画一个 11x16 的弹匣：深色匣体 + 左侧 2px 受光 + 底部 3px 黄铜底板。"""
    a = np.asarray(im).copy()
    h, w = a.shape[:2]
    for y in range(top_y, min(top_y + 16, h)):
        for x in range(grip_x, min(grip_x + 11, w)):
            if y < 0 or x < 0:
                continue
            col = dark
            if x - grip_x < 2:
                col = mid
            if y >= top_y + 13:
                col = brass
            a[y, x] = (col[0], col[1], col[2], 255)
    return Image.fromarray(a)


def emit(kind, frames):
    total = 0
    for name, im in frames:
        p = r"%s\vm_%s_%s.png" % (DST, kind, name)
        im.save(p)
        total += len(open(p, "rb").read())
    print("[%s] %d frames %d bytes" % (kind, len(frames), total))


for kind in SRC:
    im, mz = base(kind)
    w, h = im.size
    mid, dark = gun_colors(im)
    print("[%s] %dx%d muzzle=(%.1f,%.1f) palette mid=%s dark=%s"
          % (kind, w, h, mz[0], mz[1], mid, dark))

    if kind == "pistol":
        frames = [
            ("idle", im),
            ("dry", shift(im, 1, -1)),
            ("fire1", shift(im, -3, -1)),
            ("fire2", shift(im, -2, -1)),
            ("fire3", shift(im, -1, 0)),
            ("reload1", shift(im, 7)),
            ("reload2", paste_mag(shift(im, 9), h - 4, w - 44, mid, dark)),
            ("reload3", paste_mag(shift(im, 6), h - 12, w - 44, mid, dark)),
            ("reload4", shift(im, 2)),
            ("draw", shift(im, 26)),
        ]
    else:
        frames = [
            ("idle", im),
            ("fire1", shift(im, -5, -1)),
            ("fire2", shift(im, -4, -1)),
            ("fire3", shift(im, -2, 0)),
            ("fire4", shift(im, -1, 0)),
            ("fire5", shift(im, -3, 0)),
            ("reload1", shift(im, 6, 3)),
            ("reload2", shift(im, 2, 1)),
            ("draw", shift(im, 24)),
            ("altfire", shift(im, -2, 0)),
        ]
    emit(kind, frames)
