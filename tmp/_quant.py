from PIL import Image
from collections import Counter

files = ["ch03_00_player", "ch03_01_center", "ch03_02_back",
         "ch03_03_right", "ch03_04_left", "ch03_05_top"]

print("=== per-image unique channel value counts (detect palette quantization) ===")
for n in files:
    im = Image.open(r"D:\mygame\tmp\shots\chapter\%s.png" % n).convert("RGB")
    px = im.load()
    W, H = im.size
    rs, gs, bs = set(), set(), set()
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            r, g, b = px[x, y]
            rs.add(r); gs.add(g); bs.add(b)
    print("%-18s uniqueR=%3d uniqueG=%3d uniqueB=%3d" % (n, len(rs), len(gs), len(bs)))
    print("   R sorted sample:", sorted(rs)[:24])

print()
print("=== ch03_05 top view: what is the brown band? sample a grid ===")
im = Image.open(r"D:\mygame\tmp\shots\chapter\ch03_05_top.png").convert("RGB")
px = im.load()
for y in range(150, 235, 6):
    row = []
    for x in range(20, 470, 60):
        r, g, b = px[x, y]
        row.append("%3d,%3d,%3d" % (r, g, b))
    print(" y=%3d " % y + " | ".join(row))

print()
print("=== ch03_05 most common colors in y=182..222 ===")
c = Counter()
for y in range(182, 223):
    for x in range(0, 480):
        c[px[x, y]] += 1
for col, cnt in c.most_common(8):
    print("   ", col, cnt)
