"""分析 AI 生图底板的可用区域：洋红背景抠图边界 + 水印位置 + 主色。"""
import sys
from collections import Counter
from PIL import Image

for src in sys.argv[1:]:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    # 洋红判定：R 高、G 低、B 高
    def is_bg(c):
        r, g, b = c
        return r > 180 and g < 110 and b > 140

    # 背景主色采样（四角）
    corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    print("===", src, w, h)
    print("corners", corners)

    minx, miny, maxx, maxy = w, h, -1, -1
    cnt = Counter()
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            c = px[x, y]
            if is_bg(c):
                continue
            cnt[(c[0] // 16 * 16, c[1] // 16 * 16, c[2] // 16 * 16)] += 1
            if x < minx: minx = x
            if y < miny: miny = y
            if x > maxx: maxx = x
            if y > maxy: maxy = y
    print("fg bbox", (minx, miny, maxx, maxy), "size", (maxx - minx, maxy - miny))
    total = sum(cnt.values()) or 1
    for c, n in cnt.most_common(16):
        print("   rgb%-18s %5.2f%%" % (str(c), n * 100.0 / total))

    # 右下角水印区域是否与前景重叠
    print("右下 300x300 是否有前景:",
          any(not is_bg(px[x, y]) for y in range(h - 300, h, 3) for x in range(w - 300, w, 3)))
