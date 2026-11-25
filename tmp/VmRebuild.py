r"""用参考帧的正确透视重建 viewmodel：只换材质与配色，不动几何。

## 为什么不再旋转
参考帧是「枪管指向屏幕深处」的强透视压缩画面：枪身 bbox 112x250（高宽比 2.23），
能看到套筒的背面和顶面，枪口在远处变小。而 AI 底板是纯侧视剖面（高宽比 0.98），
侧视图无论怎么旋转都不可能变成透视压缩的第一视角 —— 这正是「枪管朝天花板」的根因。

用户原话（m07989）："手臂视角正确，但是手臂不是原创的手臂而是使用的星野的手臂"
→ 透视是对的，错的只是**材质**。所以只换材质、只换配色，几何原样保留。

## 三处改造
1. 藏青手套 → 裸手肤色（按明度 24/38/58/84 四档映射，保留原有体积分层）
2. 中性灰枪身 → 深蓝灰自研配色（保明度排序，只换色相/饱和度）
3. 套筒尾部加青蓝色识别条（在 gun 掩码内按相对位置定位，不用固定像素坐标）

用法: py -3 tmp/VmRebuild.py
"""
import numpy as np
from PIL import Image

SRC = {"pistol": r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png",
       "shotgun": r"D:\mygame\tmp\fp_png\Shotgun__ShotgunIdle.png"}

# 手套明度 → 肤色。暗部偏冷（指缝阴影），高光偏暖。
SKIN_LUT = {24: (150, 104, 82), 25: (150, 104, 82), 26: (150, 104, 82),
            38: (206, 158, 128), 39: (206, 158, 128), 41: (206, 158, 128),
            44: (206, 158, 128), 46: (206, 158, 128),
            57: (232, 192, 164), 58: (232, 192, 164), 59: (232, 192, 164),
            84: (246, 214, 190)}

# 中性灰枪身明度 → 纯黑磷化钢梯度。
# 取色依据：蔚蓝档案 Weapon_Icon_CH0263.png（实测彩度 0.0%、暖色 0.0%，唯一带极轻冷偏移的纯黑方案）
#   rgb(63,69,82) 22.2% / rgb(43,47,56) 12.6% / rgb(31,34,41) 13.2% / rgb(15,17,21) 11.6% / rgb(1,1,2) 12.4%
# 按参考帧原有明度排序 10/22/39/57/81/104/142 映射到上述五档 + 两档棱边高光。
# 冷通道比红通道高 8~19，模拟磷化钢；不再用深蓝灰（旧版 (54,72,102) 偏蓝，用户已否）。
GUN_LUT = {
    10: (1, 1, 2), 12: (1, 1, 2), 13: (1, 1, 2),
    22: (15, 17, 21), 26: (15, 17, 21), 28: (15, 17, 21),
    39: (31, 34, 41), 43: (31, 34, 41), 47: (31, 34, 41),
    57: (43, 47, 56), 63: (43, 47, 56), 69: (43, 47, 56),
    81: (55, 60, 71), 87: (55, 60, 71), 95: (55, 60, 71),
    104: (63, 69, 82), 112: (63, 69, 82), 120: (63, 69, 82), 122: (63, 69, 82),
    141: (88, 94, 106), 142: (88, 94, 106), 147: (88, 94, 106),
    148: (88, 94, 106), 154: (88, 94, 106), 155: (88, 94, 106),
}

# 棱边磨损高光（磷化层磨穿露钢），不是彩色识别条。
# 历史：这里原是 ACCENT=(86,214,230) / ACCENT_HI=(168,246,252) 的青色识别条，
# 被判定为科幻元素（现实枪械的标记全是同色刻印，见 docs/art_generation_todo.md B0.2），已改掉。
ACCENT = (88, 94, 106)       # GUN_LIGHT，1px 棱边高光
ACCENT_HI = (128, 136, 150)  # 高光上缘，比 GUN_LIGHT 再亮一档


def nearest(lut, key):
    return lut[key] if key in lut else lut[min(lut, key=lambda k: abs(k - key))]


def classify(a):
    rgb = a[:, :, :3].astype(np.int32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    lum = (r * 299 + g * 587 + b * 114) // 1000
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    op = a[:, :, 3] > 40
    skin = op & (r - b > 28) & (r - g > 12) & (lum > 90) & (lum < 235) & (sat < 110)
    shirt = op & (lum > 200) & (sat < 45)
    navy = op & (lum < 100) & (b > r + 18)
    gun = op & ~skin & ~shirt & ~navy
    return gun, skin, shirt, navy, op, lum


def rebuild(kind):
    im = Image.open(SRC[kind]).convert("RGBA")
    im = im.crop(im.split()[3].getbbox())
    a = np.asarray(im).copy()
    gun, skin, shirt, navy, op, lum = classify(a)

    # 1) 手套 → 裸手
    ys, xs = np.nonzero(navy)
    for y, x in zip(ys, xs):
        a[y, x, :3] = nearest(SKIN_LUT, int(lum[y, x]))

    # 2) 枪身重新配色
    ys, xs = np.nonzero(gun)
    for y, x in zip(ys, xs):
        a[y, x, :3] = nearest(GUN_LUT, int(lum[y, x]))

    # 3) 棱边磨损高光：沿 gun 掩码每一列的**最上缘**铺 1~2 px 亮灰。
    #    这是「磷化层磨穿露钢」的几何化，现实枪械唯一看得见的线。
    #    不画色块 —— 色块会变成一块突兀的方块盖在枪身上；沿轮廓线走才像磨损。
    #    只取后段（x 从 25% 到 85%），避开枪口端和握把端。
    gy, gx = np.nonzero(gun)
    gy0, gy1 = gy.min(), gy.max()
    gx0, gx1 = gx.min(), gx.max()
    span = gx1 - gx0
    painted = 0
    for x in range(gx0 + int(span * 0.25), gx0 + int(span * 0.85) + 1):
        col = np.nonzero(gun[:, x])[0]
        if col.size == 0:
            continue
        top = col.min()
        # 只在枪身上部（避免画到握把或手上）且该列有足够厚度时画
        if top > gy0 + (gy1 - gy0) * 0.55 or col.size < 3:
            continue
        a[top, x, :3] = ACCENT_HI
        if col.size >= 6:
            a[top + 1, x, :3] = ACCENT
        painted += 1
    print("[%s] %dx%d gun=%d skin_remap=%d accent_cols=%d"
          % (kind, im.width, im.height, int(gun.sum()), int(navy.sum()), painted))

    out = Image.fromarray(a)
    dst = r"D:\mygame\tmp\rb_%s.png" % kind
    out.save(dst)
    print("   -> %s" % dst)
    return out


for k in SRC:
    rebuild(k)
