"""重画场景贴图与第一人称枪械 viewmodel。

存在理由：首轮实测整幅画面平均亮度只有 6/255（墙 13、地 7、天花板 0），
枪械在画布上只占一条窄竖条且颜色与暗背景同色，视觉上等于不存在。
本脚本只重画受影响的 5 张图，不碰 AI 立绘转换出来的 4 张丧尸。

亮度余量计算：后期着色器还有 vignette / scanline 压暗，所以纹理本身必须
给足余量 —— 目标墙面亮度 90~110，落到屏幕上才剩 55~70。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_assets as G  # 复用已验证的 write_png / Canvas，不重复实现

ROOT = G.ROOT

# ── 提亮后的调色板 ──────────────────────────────────────────────────
# 原版 STONE_MID=(46,49,58) 经后期压到 13，故整体上调约 2 倍
WALL_MORTAR = (52, 55, 64, 255)
WALL_DARK = (96, 101, 114, 255)
WALL_MID = (122, 128, 142, 255)
WALL_LIGHT = (156, 162, 176, 255)
MOSS = (74, 96, 62, 255)
BLOOD_DARK = (96, 26, 24, 255)

FLOOR_BASE = (86, 90, 100, 255)
FLOOR_LIGHT = (120, 126, 138, 255)
FLOOR_DARK = (58, 61, 70, 255)
FLOOR_GRATE = (44, 47, 54, 255)

CEIL_BASE = (68, 72, 82, 255)
CEIL_RIB = (86, 90, 102, 255)
CEIL_LAMP = (198, 206, 214, 255)
CEIL_LAMP_CORE = (240, 244, 248, 255)
CEIL_GLOW = (150, 152, 138, 255)

# 枪械三级明度 + 硬描边（暗场景里靠描边读轮廓）
GUN_OUTLINE = (12, 13, 16, 255)
GUN_DARK = (40, 43, 52, 255)
GUN_MID = (92, 98, 112, 255)
GUN_LIGHT = (162, 170, 184, 255)
GUN_SPEC = (222, 228, 236, 255)
WOOD_DARK = (74, 48, 28, 255)
WOOD_MID = (118, 78, 44, 255)
WOOD_LIGHT = (156, 110, 62, 255)
GLOVE_DARK = (46, 34, 26, 255)
GLOVE_MID = (86, 62, 44, 255)
GLOVE_LIGHT = (124, 94, 66, 255)
SKIN_DARK = (108, 74, 54, 255)
SKIN_MID = (156, 112, 82, 255)


def make_wall():
    """128x128 砖墙：交错砖块 + 上沿高光 + 下沿阴影 + 苔痕血渍。"""
    c = G.Canvas(128, 128, WALL_MORTAR)
    bh, bw = 16, 32
    for row in range(128 // bh):
        y = row * bh
        offset = 0 if row % 2 == 0 else bw // 2
        for col in range(-1, 128 // bw + 2):
            x = col * bw + offset
            shade = WALL_MID if (row + col) % 3 else WALL_DARK
            c.rect(x + 1, y + 1, bw - 2, bh - 2, shade)
            c.hline(x + 1, y + 1, bw - 2, WALL_LIGHT)
            c.hline(x + 1, y + bh - 2, bw - 2, WALL_DARK)
    c.noise(0xC0FFEE, (0, 12, -6), density=0.10)
    c.noise(0xBEEF, (8, 16, 0), density=0.04)
    for (mx, my, mw, mh) in [(8, 96, 14, 6), (74, 40, 10, 4), (40, 112, 18, 5)]:
        c.rect(mx, my, mw, mh, MOSS)
    for (bx, by, bw2, bh2) in [(96, 20, 6, 10), (22, 60, 4, 7)]:
        c.rect(bx, by, bw2, bh2, BLOOD_DARK)
    c.save(os.path.join(ROOT, "textures", "wall_stone.png"))


def make_floor():
    """128x128 地砖：4x4 大方砖 + 中央格栅，缝隙压暗制造纵深。"""
    c = G.Canvas(128, 128, FLOOR_DARK)
    tile = 32
    for ty in range(4):
        for tx in range(4):
            x, y = tx * tile, ty * tile
            c.rect(x + 2, y + 2, tile - 4, tile - 4, FLOOR_BASE)
            c.hline(x + 2, y + 2, tile - 4, FLOOR_LIGHT)
            c.vline(x + 2, y + 2, tile - 4, FLOOR_LIGHT)
            c.hline(x + 2, y + tile - 3, tile - 4, FLOOR_DARK)
            c.vline(x + tile - 3, y + 2, tile - 4, FLOOR_DARK)
            # 每块砖四角的铆钉
            for (px, py) in [(x + 5, y + 5), (x + tile - 8, y + 5),
                             (x + 5, y + tile - 8), (x + tile - 8, y + tile - 8)]:
                c.rect(px, py, 3, 3, FLOOR_LIGHT)
    # 中央排水格栅
    c.rect(52, 52, 24, 24, FLOOR_GRATE)
    for i in range(0, 24, 4):
        c.vline(53 + i, 53, 22, FLOOR_DARK)
    c.outline(52, 52, 24, 24, FLOOR_LIGHT)
    c.noise(0x1234, (0, 8, -4), density=0.08)
    c.save(os.path.join(ROOT, "textures", "floor_tile.png"))


def make_ceiling():
    """128x128 天花板：暗色横向筋板 + 一盏顶灯，避免抬头全黑。"""
    c = G.Canvas(128, 128, CEIL_BASE)
    for y in range(0, 128, 16):
        c.rect(0, y, 128, 6, CEIL_RIB)
        c.hline(0, y + 6, 128, (52, 55, 64, 255))
    # 顶灯外壳
    c.rect(40, 48, 48, 32, CEIL_DARK_BOX := (46, 49, 58, 255))
    c.outline(40, 48, 48, 32, (34, 36, 44, 255))
    c.rect(44, 52, 40, 24, CEIL_GLOW)
    c.rect(48, 56, 32, 16, CEIL_LAMP)
    c.rect(54, 60, 20, 8, CEIL_LAMP_CORE)
    c.noise(0x5EED, (0, 10, -4), density=0.06)
    c.save(os.path.join(ROOT, "textures", "ceiling.png"))


def make_pistol_hud():
    """160x120 第一人称手枪：从右下伸入、枪口指向左上。

    构图要点（相对旧版的根本改动）：
    - 旧版是竖直细条、只占中间 22px 宽，在暗场景里读不出是枪。
    - 新版占满画布下半部，枪管横贯，握把与手构成右下三角，符合 FPS 惯例。
    """
    c = G.Canvas(160, 120)

    # 套筒（横贯画布，枪口朝左）
    c.rect(18, 40, 104, 26, GUN_MID)
    c.rect(18, 40, 104, 4, GUN_LIGHT)        # 顶部高光
    c.rect(18, 62, 104, 4, GUN_DARK)         # 底部阴影
    c.outline(18, 40, 104, 26, GUN_OUTLINE)
    # 套筒防滑纹
    for i in range(0, 34, 5):
        c.vline(84 + i, 44, 18, GUN_DARK)
    # 抛壳口
    c.rect(66, 46, 16, 8, (18, 19, 24, 255))

    # 枪口
    c.rect(10, 44, 10, 18, GUN_DARK)
    c.outline(10, 44, 10, 18, GUN_OUTLINE)
    c.rect(12, 47, 6, 12, (8, 8, 10, 255))
    # 前准星
    c.rect(22, 32, 8, 9, GUN_DARK)
    c.rect(24, 30, 4, 4, GUN_SPEC)
    # 后照门
    c.rect(104, 34, 12, 7, GUN_DARK)
    c.rect(107, 36, 3, 4, GUN_OUTLINE)
    c.rect(112, 36, 3, 4, GUN_OUTLINE)

    # 扳机护圈
    c.outline(74, 66, 30, 22, GUN_DARK)
    c.rect(80, 70, 18, 14, (0, 0, 0, 0))
    # 扳机
    c.rect(86, 72, 5, 10, GUN_LIGHT)

    # 握把（向右下倾斜的阶梯，模拟透视收窄）
    for i in range(12):
        w = 40 - i * 2
        c.rect(96 + i * 2, 66 + i * 4, w, 5, GUN_MID if i % 2 else GUN_DARK)
    c.vline(98, 68, 46, GUN_LIGHT)

    # 持枪的手（手套 + 指节），压在握把右下方
    c.rect(104, 84, 56, 36, GLOVE_MID)
    c.outline(104, 84, 56, 36, GLOVE_DARK)
    c.rect(104, 84, 56, 5, GLOVE_LIGHT)
    for i in range(4):
        c.rect(108 + i * 13, 92, 10, 16, GLOVE_DARK)
        c.rect(108 + i * 13, 92, 10, 4, GLOVE_LIGHT)
    # 露出的手腕皮肤
    c.rect(120, 112, 40, 8, SKIN_MID)
    c.hline(120, 112, 40, SKIN_DARK)

    # 侧面高光条：让枪在暗背景里始终有一条可读的亮边
    c.vline(19, 42, 22, GUN_SPEC)
    c.save(os.path.join(ROOT, "sprites", "weapon_pistol_hud.png"))


def make_shotgun_hud():
    """160x120 第一人称霰弹枪：双管 + 木质护木，构图同手枪。"""
    c = G.Canvas(160, 120)

    # 上下双管
    c.rect(14, 30, 108, 20, GUN_MID)
    c.rect(14, 52, 108, 20, GUN_MID)
    for y in (30, 52):
        c.rect(14, y, 108, 4, GUN_LIGHT)
        c.rect(14, y + 16, 108, 4, GUN_DARK)
        c.outline(14, y, 108, 20, GUN_OUTLINE)
        # 管口
        c.rect(8, y + 4, 8, 12, (10, 10, 12, 255))
    # 两管之间的分界暗缝
    c.hline(14, 50, 108, GUN_OUTLINE)

    # 木质护木（横跨中段）
    c.rect(40, 74, 74, 18, WOOD_MID)
    c.outline(40, 74, 74, 18, WOOD_DARK)
    c.hline(40, 74, 74, WOOD_LIGHT)
    for i in range(0, 74, 8):
        c.vline(40 + i, 76, 14, WOOD_DARK)
    # 护木上的手指凹槽
    for i in range(3):
        c.rect(48 + i * 18, 78, 12, 10, WOOD_LIGHT)

    # 机匣
    c.rect(96, 70, 44, 26, GUN_DARK)
    c.outline(96, 70, 44, 26, GUN_OUTLINE)
    c.rect(96, 70, 44, 4, GUN_MID)

    # 枪托（向右下延伸出画）
    for i in range(10):
        c.rect(112 + i * 3, 96 + i * 2, 48 - i * 3, 6, WOOD_MID if i % 2 else WOOD_DARK)

    # 手
    c.rect(60, 92, 46, 28, GLOVE_MID)
    c.outline(60, 92, 46, 28, GLOVE_DARK)
    for i in range(3):
        c.rect(64 + i * 14, 98, 11, 14, GLOVE_DARK)
        c.rect(64 + i * 14, 98, 11, 3, GLOVE_LIGHT)
    c.rect(96, 112, 34, 8, SKIN_MID)

    c.vline(15, 32, 16, GUN_SPEC)
    c.vline(15, 54, 16, GUN_SPEC)
    c.save(os.path.join(ROOT, "sprites", "weapon_shotgun_hud.png"))


if __name__ == "__main__":
    make_wall()
    make_floor()
    make_ceiling()
    make_pistol_hud()
    make_shotgun_hud()
    print("\nLOOK REGEN DONE")
