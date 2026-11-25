"""像素素材生成器：手写 PNG（无 Pillow 依赖，仅 zlib + struct）。

产物全部落到 D:/mygame/assets/ 下，供 Godot 以 Nearest 过滤导入。
设计约束（PDF）：128x128 墙面/地面贴图、64x64 纸片人、160x120 枪械 HUD、
像素风纯色块 + 抖动，禁止抗锯齿（所有绘制都是整数像素矩形）。
"""
import os
import struct
import zlib

ROOT = r"D:\mygame\assets"


def write_png(path, width, height, pixels):
    """pixels: 行优先的 (r,g,b,a) 元组列表，长度 = width*height。"""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        row = pixels[y * width:(y + 1) * width]
        for px in row:
            raw.extend(px)

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        out += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        return out

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print("wrote %-58s %dx%d" % (path.replace(ROOT + "\\", ""), width, height))


class Canvas:
    """整数像素画布，越界自动裁剪，所有操作都是硬边（无插值）。"""

    def __init__(self, w, h, fill=(0, 0, 0, 0)):
        self.w = w
        self.h = h
        self.buf = [fill] * (w * h)

    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.buf[y * self.w + x] = color

    def rect(self, x, y, w, h, color):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, color)

    def hline(self, x, y, w, color):
        self.rect(x, y, w, 1, color)

    def vline(self, x, y, h, color):
        self.rect(x, y, 1, h, color)

    def outline(self, x, y, w, h, color):
        self.hline(x, y, w, color)
        self.hline(x, y + h - 1, w, color)
        self.vline(x, y, h, color)
        self.vline(x + w - 1, y, h, color)

    def noise(self, seed, amount, density=0.06):
        """确定性伪随机噪点，用于做旧/苔痕。amount 是 RGB 偏移量。"""
        state = seed & 0xFFFFFFFF
        for y in range(self.h):
            for x in range(self.w):
                state = (1103515245 * state + 12345) & 0x7FFFFFFF
                if (state % 1000) / 1000.0 < density:
                    base = self.buf[y * self.w + x]
                    a = base[3]
                    if a == 0:
                        continue
                    self.set(x, y, (
                        clamp(base[0] + amount[0]),
                        clamp(base[1] + amount[1]),
                        clamp(base[2] + amount[2]),
                        a,
                    ))

    def save(self, path):
        write_png(path, self.w, self.h, self.buf)


def clamp(v):
    return 0 if v < 0 else (255 if v > 255 else int(v))


# ── 调色板（PDF 要求暗色恐怖基调 + 有限色数）────────────────────────
STONE_DARK = (28, 30, 38, 255)
STONE_MID = (46, 49, 58, 255)
STONE_LIGHT = (62, 66, 76, 255)
MORTAR = (18, 19, 24, 255)
MOSS = (44, 62, 40, 255)
RUST = (86, 48, 34, 255)
BLOOD = (92, 14, 14, 255)
BLOOD_DARK = (48, 8, 8, 255)
FLESH = (86, 104, 74, 255)
FLESH_DARK = (56, 70, 50, 255)
CLOTH = (58, 52, 66, 255)
BONE = (196, 190, 170, 255)
GUN_DARK = (30, 32, 38, 255)
GUN_MID = (54, 58, 68, 255)
GUN_LIGHT = (88, 94, 106, 255)
GLOW_CORE = (255, 246, 214, 255)
GLOW_MID = (255, 176, 64, 255)
GLOW_EDGE = (188, 78, 26, 255)


# ── 墙面砖块 128x128 ────────────────────────────────────────────────
def make_wall():
    c = Canvas(128, 128, MORTAR)
    brick_h = 16
    brick_w = 32
    for row in range(128 // brick_h):
        y = row * brick_h
        offset = 0 if row % 2 == 0 else brick_w // 2
        for col in range(-1, 128 // brick_w + 1):
            x = col * brick_w + offset
            shade = STONE_MID if (row + col) % 3 else STONE_DARK
            c.rect(x + 1, y + 1, brick_w - 2, brick_h - 2, shade)
            # 上沿高光 + 下沿阴影，做出砖块立体感
            c.hline(x + 1, y + 1, brick_w - 2, STONE_LIGHT)
            c.hline(x + 1, y + brick_h - 2, brick_w - 2, STONE_DARK)
    c.noise(0xC0FFEE, (0, 10, -4), density=0.10)
    c.noise(0xBEEF, (6, 14, 0), density=0.04)
    # 苔痕与血渍，打破重复感
    for (mx, my, mw, mh) in [(8, 96, 14, 6), (74, 40, 10, 4), (40, 112, 18, 5)]:
        c.rect(mx, my, mw, mh, MOSS)
    for (bx, by, bw, bh) in [(96, 20, 6, 10), (22, 60, 4, 7)]:
        c.rect(bx, by, bw, bh, BLOOD_DARK)
    c.save(os.path.join(ROOT, "textures", "wall_stone.png"))


# ── 地面 128x128 ───────────────────────────────────────────────────
def make_floor():
    c = Canvas(128, 128, STONE_DARK)
    tile = 32
    for ty in range(128 // tile):
        for tx in range(128 // tile):
            x, y = tx * tile, ty * tile
            base = STONE_MID if (tx + ty) % 2 == 0 else STONE_DARK
            c.rect(x, y, tile - 1, tile - 1, base)
            c.hline(x, y, tile - 1, STONE_LIGHT)
            c.vline(x, y, tile - 1, STONE_LIGHT)
            c.hline(x, y + tile - 2, tile - 1, MORTAR)
            c.vline(x + tile - 2, y, tile - 1, MORTAR)
    # 中央格栅（排水沟），Doom 式工业地面符号
    c.rect(48, 48, 32, 32, MORTAR)
    for i in range(0, 32, 4):
        c.vline(50 + i, 50, 28, RUST)
    c.noise(0x5EED, (0, 8, 4), density=0.09)
    c.save(os.path.join(ROOT, "textures", "floor_tile.png"))


# ── 天花板 128x128 ─────────────────────────────────────────────────
def make_ceiling():
    c = Canvas(128, 128, STONE_DARK)
    c.rect(0, 0, 128, 128, (22, 23, 30, 255))
    for y in range(0, 128, 16):
        c.hline(0, y, 128, (30, 31, 40, 255))
    for x in range(0, 128, 64):
        c.vline(x, 0, 128, (30, 31, 40, 255))
    # 一排暗淡的顶灯，提供方向感
    c.rect(52, 56, 24, 16, (58, 60, 44, 255))
    c.rect(56, 60, 16, 8, (108, 104, 68, 255))
    c.noise(0xDEAD, (0, 6, 0), density=0.08)
    c.save(os.path.join(ROOT, "textures", "ceiling.png"))


# ── 纸片人丧尸（64x64，正面朝镜头）─────────────────────────────────
def make_zombie(name, skin, cloth, eye, scale_h=64):
    c = Canvas(64, 64)
    # 头
    c.rect(24, 6, 16, 14, skin)
    c.outline(24, 6, 16, 14, FLESH_DARK)
    c.rect(27, 11, 4, 3, eye)
    c.rect(35, 11, 4, 3, eye)
    # 下颌（张嘴，露齿）
    c.rect(28, 16, 10, 3, BLOOD_DARK)
    c.rect(29, 16, 2, 2, BONE)
    c.rect(33, 16, 2, 2, BONE)
    c.rect(36, 16, 2, 2, BONE)
    # 躯干（破烂衣物）
    c.rect(22, 20, 20, 22, cloth)
    c.outline(22, 20, 20, 22, FLESH_DARK)
    c.rect(26, 24, 4, 6, BLOOD_DARK)   # 衣服上的破口
    c.rect(34, 30, 5, 4, BLOOD_DARK)
    # 前伸的双臂（Doom 丧尸标志性姿势）
    c.rect(12, 24, 10, 6, skin)
    c.outline(12, 24, 10, 6, FLESH_DARK)
    c.rect(42, 24, 10, 6, skin)
    c.outline(42, 24, 10, 6, FLESH_DARK)
    # 手（爪）
    c.rect(9, 25, 3, 4, skin)
    c.rect(52, 25, 3, 4, skin)
    # 腿
    c.rect(24, 42, 7, 18, cloth)
    c.outline(24, 42, 7, 18, FLESH_DARK)
    c.rect(33, 42, 7, 18, cloth)
    c.outline(33, 42, 7, 18, FLESH_DARK)
    # 脚
    c.rect(23, 58, 9, 4, GUN_DARK)
    c.rect(32, 58, 9, 4, GUN_DARK)
    c.noise(0x1234 + len(name), (0, 12, 0), density=0.07)
    c.save(os.path.join(ROOT, "sprites", name))


# ── 第一人称手枪 HUD（160x120，位于画面右下）────────────────────────
def make_pistol_hud():
    c = Canvas(160, 120)
    # 套筒（朝画面上方 = 枪口方向）
    c.rect(58, 18, 22, 58, GUN_MID)
    c.outline(58, 18, 22, 58, GUN_DARK)
    c.hline(60, 20, 18, GUN_LIGHT)
    # 枪管口
    c.rect(64, 12, 10, 8, GUN_DARK)
    c.rect(66, 14, 6, 4, (12, 12, 14, 255))
    # 准星
    c.rect(66, 8, 6, 4, GUN_LIGHT)
    c.rect(68, 6, 2, 3, BONE)
    # 握把（向右下倾斜的方块阶梯，模拟透视）
    for i in range(9):
        c.rect(58 + i, 76 + i * 4, 22, 5, GUN_DARK if i % 2 else GUN_MID)
    # 扳机护圈
    c.outline(80, 74, 16, 14, GUN_DARK)
    c.rect(84, 78, 8, 6, (0, 0, 0, 0))
    # 持枪的手（像素手套）
    c.rect(76, 84, 26, 20, (74, 56, 42, 255))
    c.outline(76, 84, 26, 20, (44, 32, 24, 255))
    for i in range(4):
        c.rect(78 + i * 6, 88, 4, 8, (58, 44, 34, 255))
    # 枪身侧面的高光条，让枪在暗场景里读得出来
    c.vline(60, 22, 50, GUN_LIGHT)
    c.save(os.path.join(ROOT, "sprites", "weapon_pistol_hud.png"))


def make_shotgun_hud():
    c = Canvas(160, 120)
    # 双管
    c.rect(56, 10, 12, 66, GUN_MID)
    c.rect(74, 10, 12, 66, GUN_MID)
    c.outline(56, 10, 12, 66, GUN_DARK)
    c.outline(74, 10, 12, 66, GUN_DARK)
    c.vline(58, 12, 62, GUN_LIGHT)
    c.vline(76, 12, 62, GUN_LIGHT)
    c.rect(58, 8, 8, 4, (12, 12, 14, 255))
    c.rect(76, 8, 8, 4, (12, 12, 14, 255))
    # 木质护木
    c.rect(50, 60, 44, 18, (92, 62, 38, 255))
    c.outline(50, 60, 44, 18, (52, 34, 20, 255))
    for i in range(0, 44, 6):
        c.vline(50 + i, 62, 14, (74, 48, 28, 255))
    # 手
    c.rect(70, 82, 30, 24, (74, 56, 42, 255))
    c.outline(70, 82, 30, 24, (44, 32, 24, 255))
    c.save(os.path.join(ROOT, "sprites", "weapon_shotgun_hud.png"))


# ── 枪口火光 32x32（叠加混合）──────────────────────────────────────
def make_muzzle_flash():
    c = Canvas(32, 32)
    cx, cy = 16, 16
    for r, col in [(10, GLOW_EDGE), (7, GLOW_MID), (4, GLOW_CORE)]:
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r:
                    c.set(cx + x, cy + y, col)
    # 四向星芒
    for i in range(15):
        c.set(cx - i, cy, GLOW_MID)
        c.set(cx + i, cy, GLOW_MID)
        c.set(cx, cy - i, GLOW_MID)
        c.set(cx, cy + i, GLOW_MID)
    for i in range(9):
        c.set(cx - i, cy - i, GLOW_EDGE)
        c.set(cx + i, cy - i, GLOW_EDGE)
        c.set(cx - i, cy + i, GLOW_EDGE)
        c.set(cx + i, cy + i, GLOW_EDGE)
    c.save(os.path.join(ROOT, "fx", "muzzle_flash.png"))


# ── 血雾 / 命中溅射 32x32 ──────────────────────────────────────────
def make_blood():
    c = Canvas(32, 32)
    cx, cy = 16, 16
    blobs = [(16, 16, 6), (11, 13, 4), (21, 14, 4), (13, 21, 3),
             (20, 21, 4), (9, 18, 2), (23, 19, 2)]
    for (bx, by, r) in blobs:
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r:
                    c.set(bx + x, by + y, BLOOD)
    for (bx, by, r) in [(16, 16, 3), (12, 14, 2), (20, 15, 2)]:
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r:
                    c.set(bx + x, by + y, BLOOD_DARK)
    c.save(os.path.join(ROOT, "fx", "blood_splat.png"))


# ── 弹药补给箱 32x32（世界内 Sprite3D）─────────────────────────────
def make_ammo_box():
    c = Canvas(32, 32)
    c.rect(4, 12, 24, 16, (72, 76, 48, 255))
    c.outline(4, 12, 24, 16, (38, 40, 26, 255))
    c.rect(4, 12, 24, 4, (94, 98, 62, 255))
    c.rect(13, 18, 6, 6, BONE)
    c.rect(15, 20, 2, 2, (120, 110, 70, 255))
    c.save(os.path.join(ROOT, "sprites", "ammo_box.png"))


def main():
    make_wall()
    make_floor()
    make_ceiling()
    # 杂鱼 + 四特感（用不同配色区分，Phase 1 只挂杂鱼，其余留给后续波次）
    make_zombie("zombie_fodder.png", FLESH, CLOTH, (198, 42, 30, 255))
    make_zombie("zombie_charger.png", (120, 78, 62, 255), (86, 34, 30, 255), (255, 210, 60, 255))
    make_zombie("zombie_bomber.png", (104, 118, 70, 255), (96, 88, 40, 255), (150, 255, 90, 255))
    make_zombie("zombie_screamer.png", (150, 148, 156, 255), (48, 46, 58, 255), (120, 200, 255, 255))
    make_zombie("zombie_dragger.png", (78, 66, 88, 255), (40, 34, 50, 255), (210, 120, 255, 255))
    make_pistol_hud()
    make_shotgun_hud()
    make_muzzle_flash()
    make_blood()
    make_ammo_box()
    print("\nALL ASSETS GENERATED")


if __name__ == "__main__":
    main()
