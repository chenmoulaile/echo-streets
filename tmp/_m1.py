from PIL import Image
import os, math

D = r"D:\mygame\tmp\shots\chapter"
SHOTS = ["ch03_00_player", "ch03_01_center", "ch03_02_back",
         "ch03_03_right", "ch03_04_left", "ch03_05_top"]

def L(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

print("=" * 78)
print("A. GLOBAL LUMINANCE  (L normalised 0..1, after PostFX)")
print("=" * 78)
print("%-16s %6s %6s %6s %6s %6s %6s %8s %8s" % (
    "shot", "mean", "p1", "p5", "p50", "p95", "max", "clip%", "dark%"))
data = {}
for s in SHOTS:
    im = Image.open(os.path.join(D, s + ".png")).convert("RGB")
    px = im.load()
    W, H = im.size
    data[s] = (im, px, W, H)
    ls = []
    for y in range(H):
        for x in range(W):
            c = px[x, y]
            ls.append((L(c) / 255.0, c))
    ls.sort(key=lambda t: t[0])
    n = len(ls)
    clip = sum(1 for v, _ in ls if v >= 0.985) / n * 100
    dark = sum(1 for v, _ in ls if v < 0.15) / n * 100
    print("%-16s %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %7.2f%% %7.2f%%" % (
        s, sum(v for v, _ in ls) / n, ls[n // 100][0], ls[n // 20][0],
        ls[n // 2][0], ls[19 * n // 20][0], ls[-1][0], clip, dark))

print()
print("=" * 78)
print("B. VERTICAL PROFILE, centre column x=240 (every 4 px)")
print("=" * 78)
for s in SHOTS:
    im, px, W, H = data[s]
    row = []
    for y in range(0, H, 4):
        c = px[240, y]
        row.append("%d:%d,%d,%d" % (y, c[0], c[1], c[2]))
    print(s)
    for i in range(0, len(row), 7):
        print("   " + "  ".join(row[i:i + 7]))

print()
print("=" * 78)
print("C. CLIPPED / BLOWN-OUT REGIONS  (L >= 0.96), bbox + share")
print("=" * 78)
for s in SHOTS:
    im, px, W, H = data[s]
    xs, ys, cnt = [], [], 0
    for y in range(H):
        for x in range(W):
            if L(px[x, y]) / 255.0 >= 0.96:
                cnt += 1
                xs.append(x)
                ys.append(y)
    if cnt:
        print("%-16s px=%5d (%5.1f%%)  bbox x=%d..%d y=%d..%d" % (
            s, cnt, cnt / (W * H) * 100, min(xs), max(xs), min(ys), max(ys)))
    else:
        print("%-16s none" % s)

print()
print("=" * 78)
print("D. DARK REGIONS  (L < 0.15) bbox + row histogram")
print("=" * 78)
for s in SHOTS:
    im, px, W, H = data[s]
    rows = {}
    xs, ys = [], []
    for y in range(H):
        for x in range(W):
            if L(px[x, y]) / 255.0 < 0.15:
                rows[y] = rows.get(y, 0) + 1
                xs.append(x)
                ys.append(y)
    tot = sum(rows.values())
    print("%-16s dark_px=%5d" % (s, tot))
    if tot:
        print("     bbox x=%d..%d y=%d..%d" % (min(xs), max(xs), min(ys), max(ys)))
        band = [(y, c) for y, c in sorted(rows.items()) if c > W * 0.5]
        if band:
            print("     full-width dark rows: y=%d..%d  (%d rows)" % (band[0][0], band[-1][0], len(band)))
