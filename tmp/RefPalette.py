"""分析参考帧的颜色分区，为「换手臂」重上色做准备。"""
from PIL import Image
from collections import Counter

src = r"D:\mygame\tmp\vm\Handgun__HandgunIdle.png"
im = Image.open(src).convert("RGBA")
w, h = im.size
print("size", w, h)

px = im.load()
cnt = Counter()
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a < 40:
            continue
        cnt[(r // 16 * 16, g // 16 * 16, b // 16 * 16)] += 1

total = sum(cnt.values())
print("opaque", total)
for c, n in cnt.most_common(24):
    print("  rgb%-18s %6d  %5.2f%%" % (str(c), n, n * 100.0 / total))

# 分区：按 x 和 y 粗分区域，打印各区域主色
print("\n--- 区域主色 ---")
regions = {
    "左上(枪)": (40, 0, 130, 90),
    "中(手)": (20, 80, 150, 200),
    "右下(袖/前臂)": (110, 150, 253, 266),
    "底部": (60, 200, 220, 266),
}
for name, (x0, y0, x1, y1) in regions.items():
    rc = Counter()
    for y in range(y0, min(y1, h)):
        for x in range(x0, min(x1, w)):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            rc[(r // 16 * 16, g // 16 * 16, b // 16 * 16)] += 1
    tot = sum(rc.values()) or 1
    top = ", ".join("rgb%s %.0f%%" % (str(c), n * 100.0 / tot) for c, n in rc.most_common(4))
    print("%-14s n=%5d  %s" % (name, tot, top))
