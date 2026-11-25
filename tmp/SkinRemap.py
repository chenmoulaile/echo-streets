r"""把参考帧的藏青手套重上色成裸手，保留其透视、轮廓与明暗结构。

用户已经明确说过「手臂视角正确，但是手臂不是原创的手臂而是使用的星野的手臂」——
即参考帧的**透视是对的**，错的只是手套这个材质。所以正确做法不是重新生成
（生图服务持续 504），也不是旋转（侧视剖面旋转不可能变成透视压缩），
而是**只换材质、不动几何**。

手套实测只有 4 档明度：24/25（暗部）、38/39（中间调）、58（高光）、84（边缘）。
按明度排序映射到肤色三档，保持原有的体积分层。

用法: py -3 tmp/SkinRemap.py
"""
from PIL import Image
import numpy as np

SRC = {
    "pistol": r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png",
    "shotgun": r"D:\mygame\tmp\fp_png\Shotgun__ShotgunIdle.png",
}

# 藏青手套明度 → 肤色。保留「暗/中/亮」三档的相对关系，色相统一到暖肤色。
SKIN_LUT = {
    24: (150, 104, 82),    # 暗部（指缝阴影）
    25: (150, 104, 82),
    26: (150, 104, 82),
    38: (206, 158, 128),   # 中间调（指背主色）
    39: (206, 158, 128),
    41: (206, 158, 128),
    44: (206, 158, 128),
    46: (206, 158, 128),
    57: (232, 192, 164),   # 高光（受光指背）
    58: (232, 192, 164),
    59: (232, 192, 164),
    84: (246, 214, 190),   # 边缘反光
}


def remap(a):
    """把 navy 掩码内的像素按明度替换成肤色，其余原样返回。"""
    out = a.copy()
    rgb = a[:, :, :3].astype(np.int32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    navy = (a[:, :, 3] > 40) & (lum < 100) & (b > r + 18)
    ys, xs = np.nonzero(navy)
    hit = 0
    for y, x in zip(ys, xs):
        key = int(lum[y, x])
        # 找最近的 LUT 键，避免漏掉个别抖动值
        if key not in SKIN_LUT:
            key = min(SKIN_LUT, key=lambda k: abs(k - key))
        out[y, x, 0], out[y, x, 1], out[y, x, 2] = SKIN_LUT[key]
        hit += 1
    return out, hit, int(navy.sum())


for kind, path in SRC.items():
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.split()[3].getbbox())
    a = np.asarray(im)
    out, hit, total = remap(a)
    print("[%s] %dx%d  navy=%d  remapped=%d" % (kind, im.width, im.height, total, hit))
    dst = r"D:\mygame\tmp\skin_%s.png" % kind
    Image.fromarray(out).save(dst)
    print("   -> %s" % dst)
