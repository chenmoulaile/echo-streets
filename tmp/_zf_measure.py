from PIL import Image

for n in ["_zf_left", "_zf_right"]:
    im = Image.open(r"D:\mygame\tmp\%s.png" % n).convert("RGB")
    W, H = im.size
    px = im.load()
    yellow = 0
    for y in range(30, 160):
        for x in range(120, 360):
            r, g, b = px[x, y]
            if r > 120 and g > 110 and b < 90 and r - b > 60:
                yellow += 1
    blue = 0
    for y in range(135, 195):
        for x in range(0, W):
            r, g, b = px[x, y]
            if b > 60 and b - r > 25:
                blue += 1
    print(n, "size", (W, H), "yellow_in_sign_band =", yellow, "blue_in_skirt_band =", blue)
    # 逐行 luma，找墙裙边界
    for y in range(130, 200, 4):
        tot = 0.0
        for x in range(0, W):
            r, g, b = px[x, y]
            tot += 0.299 * r + 0.587 * g + 0.114 * b
        print("   y=%3d meanL=%.1f" % (y, tot / W / 255.0))
