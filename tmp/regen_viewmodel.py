"""重画第一人称枪械 viewmodel：沿主轴/法向坐标填充斜矩形，得到方正的枪身。

存在理由（三次迭代的教训）：
1. "逐列竖矩形堆叠"画斜带，45° 方向实际垂直宽度被压缩 -> 细棍。
2. "圆头胶囊"沿轴填充，厚度对了但端头是圆的 -> 读成一根管子。
3. 斜矩形对了，但主轴横贯整张画布（45° 对角线）-> 贴到 HUD 上是一条斜杠，
   不是一支枪。FPS viewmodel 的枪身必须接近竖直：枪口朝画面中上方，
   握把朝下出画，这样才有"握在手里、指向远处"的透视。

构图（Doom 式）：枪身近竖直、略向左倾，枪口在画面上部，握把与手在底部出画。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regen_look as R

ROOT = R.G.ROOT

GLOVE_OUTLINE = (18, 18, 22, 255)
GLOVE_SHADOW = (38, 40, 46, 255)
GLOVE_BODY = (74, 78, 88, 255)
GLOVE_HIGH = (118, 124, 136, 255)
PITCH_BLACK = (8, 8, 10, 255)


def _frame(x0, y0, x1, y1):
    """返回 (ux,uy,nx,ny,length)：主轴单位向量、法向单位向量、轴长。"""
    dx, dy = float(x1 - x0), float(y1 - y0)
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    return ux, uy, -uy, ux, length


def bar(c, x0, y0, x1, y1, half_w, color,
        u0=0.0, u1=1.0, v0=-1.0, v1=1.0):
    """填充斜矩形：u∈[u0,u1] 沿轴、v∈[v0,v1] 乘 half_w 为法向半宽。

    端头是垂直于主轴的斜切平面（不是圆头），这是"方枪身"的关键。
    """
    ux, uy, nx, ny, length = _frame(x0, y0, x1, y1)
    lo, hi = v0 * half_w, v1 * half_w
    for y in range(c.h):
        py = y + 0.5 - y0
        for x in range(c.w):
            px = x + 0.5 - x0
            u = (px * ux + py * uy) / length
            if u < u0 or u > u1:
                continue
            v = px * nx + py * ny
            if lo <= v <= hi:
                c.set(x, y, color)


def bar_banded(c, x0, y0, x1, y1, half_w, bands, u0=0.0, u1=1.0):
    """按 v 分带填充：bands = [(v_start, v_end, color), ...]。

    用于滑套：上表面高光 / 侧面主色 / 下缘阴影三段，制造方柱体积感。
    """
    for v0, v1, color in bands:
        bar(c, x0, y0, x1, y1, half_w, color, u0, u1, v0, v1)


def _hand(c, x0, y0, x1, y1, hw, fingers):
    """手套：本体 + 分带明暗 + 若干手指（横勒过握把）。"""
    bar(c, x0, y0, x1, y1, hw + 2.0, GLOVE_OUTLINE)
    bar_banded(c, x0, y0, x1, y1, hw, [
        (-1.0, -0.38, GLOVE_HIGH),
        (-0.38, 0.48, GLOVE_BODY),
        (0.48, 1.0, GLOVE_SHADOW),
    ])
    for i in range(fingers):
        u = 0.10 + i * (0.80 / fingers)
        bar(c, x0, y0, x1, y1, hw, GLOVE_OUTLINE, u, u + 0.15, -0.92, 0.82)
        bar(c, x0, y0, x1, y1, hw, GLOVE_HIGH, u + 0.02, u + 0.13, -0.92, -0.52)


def make_pistol_hud():
    """160x120 手枪：近竖直枪身，枪口朝上，握把与手在底部出画。"""
    c = R.G.Canvas(160, 120)
    # 主轴：机匣 (116,82) -> 枪口 (102,18)。接近竖直、略向左倾。
    ax0, ay0, ax1, ay1 = 116.0, 82.0, 102.0, 18.0
    HW = 12.0

    # --- 滑套：描边 -> 三段明暗（上表面亮、右侧面中、左下缘暗）---
    bar(c, ax0, ay0, ax1, ay1, HW + 2.0, R.GUN_OUTLINE, 0.02, 1.0)
    bar_banded(c, ax0, ay0, ax1, ay1, HW, [
        (-1.0, -0.30, R.GUN_LIGHT),   # 上表面
        (-0.30, 0.42, R.GUN_MID),     # 右侧面
        (0.42, 1.0, R.GUN_DARK),      # 左下缘
    ], 0.04, 0.985)
    # 上棱线最亮一条
    bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_SPEC, 0.08, 0.96, -0.96, -0.74)

    # --- 枪口端面：斜切平面 + 黑孔 ---
    bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_OUTLINE, 0.985, 1.0, -1.0, 1.0)
    bar(c, ax0, ay0, ax1, ay1, HW, PITCH_BLACK, 1.0, 1.04, -0.55, 0.30)
    bar(c, ax0, ay0, ax1, ay1, HW, (30, 32, 38, 255), 0.955, 0.985, -0.85, 0.62)

    # --- 前准星：滑套顶部凸起 ---
    bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_OUTLINE, 0.86, 0.93, -1.40, -0.95)
    bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_MID, 0.875, 0.915, -1.30, -1.00)

    # --- 抛壳口 ---
    bar(c, ax0, ay0, ax1, ay1, HW, (14, 15, 19, 255), 0.50, 0.62, -0.55, -0.02)

    # --- 套筒防滑纹：垂直主轴的细线 ---
    for i in range(6):
        u = 0.66 + i * 0.045
        bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_DARK, u, u + 0.015, -0.30, 0.52)
        bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_LIGHT, u - 0.012, u, -0.30, 0.52)

    # --- 后照门：机匣上缘的缺口 ---
    bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_OUTLINE, 0.10, 0.17, -1.36, -0.90)
    bar(c, ax0, ay0, ax1, ay1, HW, PITCH_BLACK, 0.115, 0.155, -1.26, -1.00)

    # --- 机匣：比滑套宽一圈 ---
    bar(c, ax0, ay0, ax1, ay1, HW + 3.5, R.GUN_OUTLINE, 0.0, 0.20)
    bar(c, ax0, ay0, ax1, ay1, HW + 1.5, R.GUN_DARK, 0.0, 0.18, -0.95, 0.95)
    bar(c, ax0, ay0, ax1, ay1, HW + 1.5, R.GUN_MID, 0.0, 0.18, -0.95, -0.30)

    # --- 握把：从机匣底部向右下出画 ---
    gx0, gy0, gx1, gy1 = 112.0, 78.0, 132.0, 124.0
    bar(c, gx0, gy0, gx1, gy1, 13.0, R.GUN_OUTLINE)
    bar_banded(c, gx0, gy0, gx1, gy1, 11.0, [
        (-1.0, -0.28, R.GUN_MID),
        (-0.28, 0.55, R.GUN_DARK),
        (0.55, 1.0, (22, 23, 28, 255)),
    ])
    for i in range(4):
        v = -0.55 + i * 0.32
        bar(c, gx0, gy0, gx1, gy1, 11.0, (26, 27, 33, 255), 0.28, 0.74, v, v + 0.11)

    # --- 手：包住握把 ---
    _hand(c, 104.0, 76.0, 140.0, 116.0, 17.0, 4)
    # 虎口接缝：握把上缘与手背的交界
    bar(c, 104.0, 76.0, 140.0, 116.0, 17.0, (12, 12, 15, 255), 0.90, 1.0, -1.0, 1.0)
    # 手腕皮肤：出画下缘留一小截，让"手"有落点
    bar(c, 118.0, 104.0, 148.0, 140.0, 12.0, R.SKIN_DARK)
    bar(c, 118.0, 104.0, 148.0, 140.0, 9.0, R.SKIN_MID)

    c.save(os.path.join(ROOT, "sprites", "weapon_pistol_hud.png"))


def make_shotgun_hud():
    """160x120 霰弹枪：双管近竖直 + 木质护木 + 机匣 + 枪托。"""
    c = R.G.Canvas(160, 120)
    ax0, ay0, ax1, ay1 = 118.0, 86.0, 104.0, 12.0
    HW = 15.0

    # --- 上下双管（各占 v 的一半，中间留暗缝）---
    for v_lo, v_hi in ((-0.95, -0.05), (0.05, 0.95)):
        bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_OUTLINE, 0.30, 1.0, v_lo, v_hi)
        bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_MID, 0.32, 0.985, v_lo + 0.08, v_hi - 0.08)
        bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_LIGHT, 0.34, 0.97, v_lo + 0.08, v_lo + 0.30)
        bar(c, ax0, ay0, ax1, ay1, HW, (24, 25, 30, 255), 0.34, 0.97, v_hi - 0.24, v_hi - 0.08)
    bar(c, ax0, ay0, ax1, ay1, HW, (10, 10, 13, 255), 0.30, 1.0, -0.05, 0.05)

    # --- 管口：两个黑孔 ---
    bar(c, ax0, ay0, ax1, ay1, HW, PITCH_BLACK, 1.0, 1.05, -0.80, -0.20)
    bar(c, ax0, ay0, ax1, ay1, HW, PITCH_BLACK, 1.0, 1.05, 0.20, 0.80)
    bar(c, ax0, ay0, ax1, ay1, HW, R.GUN_OUTLINE, 0.975, 1.0, -0.95, 0.95)

    # --- 木质护木：横跨双管中段，比管更粗 ---
    bar(c, ax0, ay0, ax1, ay1, HW + 5.0, R.WOOD_DARK, 0.44, 0.74, -1.15, 1.15)
    bar_banded(c, ax0, ay0, ax1, ay1, HW + 3.5, [
        (-1.0, -0.45, R.WOOD_LIGHT),
        (-0.45, 0.35, R.WOOD_MID),
        (0.35, 1.0, R.WOOD_DARK),
    ], 0.45, 0.73)
    # 护木上的手指凹槽：只刻上表面，横跨全宽会读成木板纹理
    for i in range(4):
        u = 0.48 + i * 0.062
        bar(c, ax0, ay0, ax1, ay1, HW + 3.5, R.WOOD_DARK, u, u + 0.018, -0.98, -0.40)

    # --- 机匣 ---
    bar(c, ax0, ay0, ax1, ay1, HW + 4.5, R.GUN_OUTLINE, 0.08, 0.42, -1.02, 1.02)
    bar(c, ax0, ay0, ax1, ay1, HW + 2.5, R.GUN_DARK, 0.10, 0.40, -0.94, 0.94)
    bar(c, ax0, ay0, ax1, ay1, HW + 2.5, R.GUN_MID, 0.10, 0.40, -0.94, -0.32)
    bar(c, ax0, ay0, ax1, ay1, HW + 2.5, (12, 13, 17, 255), 0.20, 0.32, -0.52, 0.12)

    # --- 枪托：向右下出画 ---
    sx0, sy0, sx1, sy1 = 128.0, 84.0, 154.0, 130.0
    bar(c, sx0, sy0, sx1, sy1, 18.0, R.WOOD_DARK)
    bar_banded(c, sx0, sy0, sx1, sy1, 16.0, [
        (-1.0, -0.40, R.WOOD_MID),
        (-0.40, 0.60, R.WOOD_DARK),
        (0.60, 1.0, (58, 38, 22, 255)),
    ])

    # --- 手（握护木）：冷灰手套，与暖棕木料拉开色相差 ---
    _hand(c, 86.0, 62.0, 126.0, 100.0, 16.0, 3)
    # 手腕皮肤
    bar(c, 104.0, 90.0, 138.0, 128.0, 11.0, R.SKIN_DARK)
    bar(c, 104.0, 90.0, 138.0, 128.0, 8.0, R.SKIN_MID)

    c.save(os.path.join(ROOT, "sprites", "weapon_shotgun_hud.png"))


if __name__ == "__main__":
    make_pistol_hud()
    make_shotgun_hud()
    print("\nVIEWMODEL V4 DONE")
