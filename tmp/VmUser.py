r"""把**用户自己生成**的手枪母图转成 viewmodel 帧（洋红抠图 + 绕握把旋转）。

与 tmp/AiPrep.py 的区别：
  AiPrep 假设 1920x1920 且右下角有「AI生成」水印，按固定矩形擦除；
  本脚本处理的是用户直接产出的 1248x512 图，**没有水印**，洋红是纯色
  (188,2,142)，所以改用连续 alpha 抠图 + 边缘去洋红污染（color bleed）。

洋红判据用 min(r-g, b-g)：纯洋红 = 140，白色 = 0，肤色 = -33，深藏青 = -2。
白袖口和肤色不会被误抠。

为什么这一版要绕握把旋转（v3，取代 v1/v2 的纯平移）：
  现实里换弹时枪不会整把滑出画面 —— 射手把枪口下压、露出弹匣井，换完再抬回。
  v1 的「整张图上下平移」实机读成「枪掉下去了」，用户明确说换弹动作不对。
  旋转必须在**全分辨率母图**上做再降采样：先降采样再旋转会把像素网格重采样
  两次，边缘糊成一团。旋转轴取手部质心（握把），枪口随之下压，前臂跟着转 ——
  这正是单手持枪换弹时手臂的真实姿态。

v2 的两个穿帮与修法（都别再犯）：
  1) 旋转后手臂末端会离开画布下沿，按列复制最底像素去补 → 细窄边缘列被拉成
     一条条竖线（实测肉眼可见的色带）。修法：**先在母图上整行延伸手臂**，
     再旋转；旋转后手臂末端仍在画外。
  2) 所有帧共用同一块画布（TextureRect 是 STRETCH_SCALE，帧尺寸不一致会被
     拉伸变形），所以画布必须按「握把固定、窗口固定」来裁，而不是按每帧内容
     bbox 裁 —— 否则枪在动画里会抖。
  窗口下沿刻意低于手臂末端：手臂永远从画面底边出画，与真实第一视角一致。

用法: py -3 tmp/VmUser.py pistol D:\mygame\vm_pistol_idle.png
"""
import math
import sys

import numpy as np
from PIL import Image

DST = r"D:\mygame\assets\sprites\viewmodel"
## 枪身在成品里的高度（像素）。窗口比它高，多出来的部分是手臂。
GUN_H = 150
## 手臂在母图上向下延伸的比例（相对裁切后高度）。够长才能保证任何旋转角下
## 手臂末端都在窗口外 —— 否则旋转后末端翘进画面，露出一条斜切边。
ARM_EXTEND = 0.60
## 握把在窗口里的位置：上方留给枪身，下方留给手臂出画。
UP = 132
DOWN = 56
COLORS = 24

# 洋红底实测值（用户图四角取样一致）
MAGENTA = np.array([188, 2, 142], dtype=np.int32)
BG_HI = 100.0
BG_LO = 40.0

# 每帧: (名字, 角度[正=枪口下压], 下移px, 右移px)。平移单位是成品像素。
PISTOL_FRAMES = [
    ("idle", 0.0, 0, 0),
    ("dry", 0.0, 1, -1),
    # 开火：枪口上跳（负角）+ 整体上移，后坐感来自角度与位移叠加
    ("fire1", -4.0, -4, -1),
    ("fire2", -3.0, -3, -1),
    ("fire3", -1.0, -1, 0),
    # 换弹：枪口下压露出弹匣井，中段压到最深，末段抬回
    ("reload1", 8.0, 2, 1),
    ("reload2", 21.0, 7, 3),
    ("reload3", 14.0, 4, 2),
    ("reload4", 4.0, 1, 1),
    ("draw", 0.0, 34, 0),
]


def key_magenta(im):
    """连续 alpha 抠洋红 + 用不透明邻居色修补边缘 RGB。"""
    a = np.asarray(im.convert("RGB")).astype(np.int32)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    m = np.minimum(r - g, b - g).astype(np.float32)

    alpha = np.clip((BG_HI - m) / (BG_HI - BG_LO), 0.0, 1.0)
    alpha = (alpha * 255.0).astype(np.uint8)

    rgb = a.copy()
    solid = alpha >= 250
    # color bleed：半透明像素的 RGB 被洋红污染，逐轮用不透明邻居的均值覆盖，
    # 否则降采样后边缘会出现一圈粉色描边。
    edge = (alpha > 0) & ~solid
    for _ in range(6):
        if not edge.any():
            break
        acc = np.zeros_like(rgb, dtype=np.int32)
        cnt = np.zeros(alpha.shape, dtype=np.int32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            src_rgb = np.roll(np.roll(rgb, dy, axis=0), dx, axis=1)
            src_ok = np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
            acc += np.where(src_ok[:, :, None], src_rgb, 0)
            cnt += src_ok.astype(np.int32)
        take = edge & (cnt > 0)
        if not take.any():
            break
        rgb[take] = (acc[take] / cnt[take][:, None]).astype(np.int32)
        solid = solid | take
        edge = (alpha > 0) & ~solid

    out = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def quantize(im):
    """RGBA 不能用 MEDIANCUT，剥 alpha 走 RGB 量化再贴回。"""
    alpha = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT,
                                     dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def extend_arm(cut, factor):
    """把手臂向下延伸（母图的手臂是平切在图片底边的）。

    必须在旋转**之前**做：整行复制底行得到一块矩形延长，旋转后仍是连续的手臂；
    反过来「旋转完再按列补最底像素」会把细窄边缘列拉成竖线（v2 的穿帮）。
    """
    a = np.asarray(cut)
    h, w = a.shape[:2]
    ext = int(h * factor)
    out = np.zeros((h + ext, w, 4), dtype=a.dtype)
    out[:h] = a
    bottom = a[h - 1]
    mask = bottom[:, 3] > 0
    out[h:, mask] = bottom[mask]
    return Image.fromarray(out, "RGBA")


def grip_pivot(cut):
    """握把旋转轴：手部（肤色）质心。

    判据与 tmp/VmRebuild.py 的 classify 同一套，这里只需要肤色一类。
    没有肤色像素时退化成整块前景质心，保证不会除零。
    """
    a = np.asarray(cut).astype(np.int32)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    op = a[:, :, 3] > 40
    lum = (r * 299 + g * 587 + b * 114) // 1000
    sat = a[:, :, :3].max(axis=2) - a[:, :, :3].min(axis=2)
    skin = op & (r - b > 28) & (r - g > 12) & (lum > 90) & (lum < 235) & (sat < 110)
    mask = skin if skin.sum() > 200 else op
    ys, xs = np.nonzero(mask)
    return float(xs.mean()), float(ys.mean()), int(skin.sum())


def rot_extent(w, h, pivot, angles):
    """所有帧旋转后的外接矩形（相对旋转轴），用于确定旋转画布尺寸。"""
    px, py = pivot
    corners = [(0, 0), (w, 0), (w, h), (0, h)]
    xs, ys = [], []
    for a in angles:
        t = math.radians(a)
        c, s = math.cos(t), math.sin(t)
        for x, y in corners:
            dx, dy = x - px, y - py
            xs.append(dx * c + dy * s)
            ys.append(-dx * s + dy * c)
    return min(xs), max(xs), min(ys), max(ys)


def build(src, frames):
    keyed = key_magenta(Image.open(src))
    box = keyed.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
    print("[key] src=%s bbox=%s" % (src, box))
    cut = keyed.crop(box)
    cw, ch = cut.size
    gun_h = float(ch)

    px, py, skin_n = grip_pivot(cut)
    print("[pivot] grip=(%.1f,%.1f) in cut  skin_px=%d" % (px, py, skin_n))

    long_cut = extend_arm(cut, ARM_EXTEND)
    lw, lh = long_cut.size
    print("[arm] cut=%dx%d -> %dx%d" % (cw, ch, lw, lh))

    angles = [f[1] for f in frames]
    x0, x1, y0, y1 = rot_extent(lw, lh, (px, py), angles)
    cw_full = int(math.ceil(x1 - x0)) + 2
    ch_full = int(math.ceil(y1 - y0)) + 2
    pivot_canvas = (float(-x0) + 1.0, float(-y0) + 1.0)
    base = Image.new("RGBA", (cw_full, ch_full), (0, 0, 0, 0))
    base.alpha_composite(long_cut, (int(round(pivot_canvas[0] - px)),
                                    int(round(pivot_canvas[1] - py))))
    print("[canvas] %dx%d pivot=(%.1f,%.1f) extent x[%.0f,%.0f] y[%.0f,%.0f]"
          % (cw_full, ch_full, pivot_canvas[0], pivot_canvas[1], x0, x1, y0, y1))

    # 缩放只跟**原始枪身高度**走：手臂延长不能把枪缩小。
    s = GUN_H / gun_h
    # 窗口：横向按所有帧的旋转范围给足，纵向 = 枪身 + 手臂出画余量。
    # 平移量也计入横向余量，否则左右移帧会被窗口裁掉一截。
    pad_x = max([abs(f[3]) for f in frames] + [0]) + 2
    wl = int(math.ceil(-x0 * s)) + pad_x
    wr = int(math.ceil(x1 * s)) + pad_x
    out_w = wl + wr
    out_h = UP + DOWN

    # 窗口可能超出旋转画布（枪口在握把左上方，窗口左沿会跑到画布外）。
    # 给画布补白边，让所有帧的窗口四边都落在画布内，避免 resize 的负偏移。
    # 注意要把每帧的平移量算进去 —— 只看 wl/wr 会漏掉左右移动的帧。
    need_l = min(pivot_canvas[0] - wl / s - f[3] / s for f in frames)
    need_t = min(pivot_canvas[1] - UP / s - f[2] / s for f in frames)
    need_r = max(pivot_canvas[0] + wr / s - f[3] / s for f in frames)
    need_b = max(pivot_canvas[1] + DOWN / s - f[2] / s for f in frames)
    pad_l = max(0, int(math.ceil(-need_l)) + 1)
    pad_t = max(0, int(math.ceil(-need_t)) + 1)
    pad_r = max(0, int(math.ceil(need_r - cw_full)) + 1)
    pad_b = max(0, int(math.ceil(need_b - ch_full)) + 1)
    if pad_l or pad_t or pad_r or pad_b:
        padded = Image.new("RGBA", (cw_full + pad_l + pad_r, ch_full + pad_t + pad_b),
                           (0, 0, 0, 0))
        padded.alpha_composite(base, (pad_l, pad_t))
        base = padded
        pivot_canvas = (pivot_canvas[0] + pad_l, pivot_canvas[1] + pad_t)
        print("[pad] l=%d t=%d r=%d b=%d -> canvas %dx%d"
              % (pad_l, pad_t, pad_r, pad_b, base.size[0], base.size[1]))
    print("[window] %dx%d  grip=(%d,%d)  scale=%.4f" % (out_w, out_h, wl, UP, s))

    out = []
    for name, deg, dy, dx in frames:
        if abs(deg) > 1e-6:
            rot = base.rotate(deg, resample=Image.BICUBIC, expand=False,
                              center=pivot_canvas)
        else:
            rot = base
        # 平移必须靠**移动采样窗口**实现，不能平移成品图：
        # 成品图平移会在底边留出全透明行，实机后坐瞬间闪出下方地面。
        # 窗口下移 = 内容上移，而手臂在画布里继续向下延伸，底边永远有像素。
        box_l = pivot_canvas[0] - wl / s - dx / s
        box_t = pivot_canvas[1] - UP / s - dy / s
        box_r = pivot_canvas[0] + wr / s - dx / s
        box_b = pivot_canvas[1] + DOWN / s - dy / s
        win = rot.resize((out_w, out_h), Image.BOX,
                         box=(box_l, box_t, box_r, box_b))
        out.append((name, quantize(win)))

    a = np.asarray(out[0][1])
    ys, xs = np.nonzero(a[:, :, 3] > 40)
    top = int(ys.min())
    mz_x = float(xs[ys <= top + 4].mean())
    colors = len(np.unique(a[:, :, :3][a[:, :, 3] > 40].reshape(-1, 3), axis=0))
    print("[frame] %dx%d colors=%d idle_bbox x[%d,%d] y[%d,%d] muzzle=(%.1f,%.1f)"
          % (out_w, out_h, colors, xs.min(), xs.max(), top, ys.max(), mz_x, float(top)))
    return out


def main():
    kind = sys.argv[1]
    src = sys.argv[2]
    out = build(src, PISTOL_FRAMES)
    w, h = out[0][1].size
    total = 0
    for name, im in out:
        p = r"%s\vm_%s_%s.png" % (DST, kind, name)
        im.save(p)
        total += len(open(p, "rb").read())
    print("[%s] %d frames %d bytes  size=%dx%d" % (kind, len(out), total, w, h))


main()
