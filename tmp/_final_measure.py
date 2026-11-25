from PIL import Image

# 1) ch03_03 / ch03_04 招牌应出现的屏幕行：相机(±7,1.6,2)，墙面 x=±13，招牌 x=±12.62 y=2.05
#    fov 75, 270px -> 3.6 px/deg；dy=0.45, 水平距 5.38 -> 上移 4.8deg -> 17px -> y≈118
for n in ["ch03_03_right", "ch03_04_left"]:
    im = Image.open(r"D:\mygame\tmp\shots\chapter\%s.png" % n).convert("RGB")
    px = im.load()
    print("=== %s ===" % n)
    for y in range(104, 136, 2):
        row = []
        for x in range(60, 430, 60):
            r, g, b = px[x, y]
            row.append("%3d,%3d,%3d" % (r, g, b))
        print("  y=%3d " % y + " ".join(row))

# 2) ch03_05 二层楼板顶面 vs 中庭地面：同一列，跨挑空边界
im = Image.open(r"D:\mygame\tmp\shots\chapter\ch03_05_top.png").convert("RGB")
px = im.load()
print("=== ch03_05 vertical scan x=240 (二层->挑空->地面) ===")
for y in range(160, 232, 2):
    r, g, b = px[240, y]
    print("  y=%3d rgb=(%3d,%3d,%3d) L=%.3f" % (y, r, g, b, (0.299*r+0.587*g+0.114*b)/255.0))

# 3) ch03_00 天花 vs 地面：证明天花朝下取 amb_ground
im0 = Image.open(r"D:\mygame\tmp\shots\chapter\ch03_00_player.png").convert("RGB")
p0 = im0.load()
def box(im, x0, y0, x1, y1):
    s = 0.0; n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = im.getpixel((x, y))
            s += 0.299*r + 0.587*g + 0.114*b; n += 1
    return s / n / 255.0
print("ch03_00 ceiling L = %.3f" % box(im0, 150, 0, 330, 55))
print("ch03_00 floor   L = %.3f" % box(im0, 150, 210, 330, 268))
