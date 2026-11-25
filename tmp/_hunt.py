from PIL import Image

files = ["ch03_00_player", "ch03_01_center", "ch03_02_back",
         "ch03_03_right", "ch03_04_left", "ch03_05_top"]

print("=== full-frame search for WARNING-YELLOW pixels (hue 40-70, sat>0.35, val>0.25) ===")
for n in files:
    im = Image.open(r"D:\mygame\tmp\shots\chapter\%s.png" % n).convert("RGB")
    px = im.load()
    W, H = im.size
    hits = []
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            if mx < 60:
                continue
            sat = (mx - mn) / float(mx)
            if sat < 0.35:
                continue
            # yellow-ish: r and g both high, b low
            if r > 60 and g > 55 and b < g * 0.72 and abs(r - g) < 60:
                hits.append((x, y, r, g, b))
    print("%-18s yellow_px=%5d" % (n, len(hits)), end="")
    if hits:
        xs = [h[0] for h in hits]; ys = [h[1] for h in hits]
        print("  bbox x=%d..%d y=%d..%d  sample=%s" % (min(xs), max(xs), min(ys), max(ys), hits[0][2:]))
    else:
        print()

print()
print("=== full-frame search for BLUE-TILE wall-skirt pixels (PoolTiles, hue ~200, sat>0.30) ===")
for n in files:
    im = Image.open(r"D:\mygame\tmp\shots\chapter\%s.png" % n).convert("RGB")
    px = im.load()
    W, H = im.size
    hits = []
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            if mx < 55:
                continue
            sat = (mx - mn) / float(mx)
            if sat < 0.30:
                continue
            if b > r + 25 and b >= g:
                hits.append((x, y))
    print("%-18s bluetile_px=%5d" % (n, len(hits)), end="")
    if hits:
        xs = [h[0] for h in hits]; ys = [h[1] for h in hits]
        print("  bbox x=%d..%d y=%d..%d" % (min(xs), max(xs), min(ys), max(ys)))
    else:
        print()
