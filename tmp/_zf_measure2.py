from PIL import Image

# 招牌：x=+-12.62，相机 6.62m 远，中心 y=2.05，相机 y=1.6
# 垂直半屏 tan(37.5)=0.7671 -> 6.62m 处半屏高 5.078m，135px -> 0.03761 m/px
# 招牌中心 dy=+0.45 -> 上移 12.0px -> y=123；高 0.42m -> +-5.6px -> y=117..129
for n in ["_zf_left", "_zf_right"]:
    im = Image.open(r"D:\mygame\tmp\%s.png" % n).convert("RGB")
    px = im.load()
    print("=== %s ===" % n)
    for y in range(112, 136, 2):
        row = []
        for x in range(200, 285, 10):
            r, g, b = px[x, y]
            row.append("%3d,%3d,%3d" % (r, g, b))
        print("  y=%3d  " % y + "  ".join(row))
    # 墙裙 vs 墙的分界：左图 y=148..152 有无突变
    print("  --- skirt check, x=240 column ---")
    for y in range(140, 190, 2):
        r, g, b = px[240, y]
        print("   y=%3d rgb=(%3d,%3d,%3d)" % (y, r, g, b))
