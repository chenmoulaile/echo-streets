import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

f = 'ch01_00_player'
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
print('w=%d h=%d  len(rows)=%d  len(rows[0])=%d' % (w, h, len(rows), len(rows[0])))
print('rows[0][0] =', rows[0][0], type(rows[0][0]))
# 手工统计 >=250 的位置分布
cnt = 0
xs = []
ys = []
for y in range(h):
    for x in range(w):
        px = rows[y][x]
        L = lum(px[0], px[1], px[2])
        if L >= 250:
            cnt += 1
            xs.append(x); ys.append(y)
print('>=250 count=%d (%.2f%%)' % (cnt, 100.0*cnt/(w*h)))
if cnt:
    print('  x range %d..%d  y range %d..%d' % (min(xs), max(xs), min(ys), max(ys)))
    # 按区域统计
    inner = sum(1 for x, y in zip(xs, ys) if 8 <= x < w-8 and 8 <= y < h-8)
    print('  inner(8px border excluded)=%d  border=%d' % (inner, cnt-inner))
    # 前 20 个坐标
    print('  first20=', list(zip(xs[:20], ys[:20])))
    print('  last20=', list(zip(xs[-20:], ys[-20:])))
# 逐行打印 y=0..12 的 x=60..100 的原始像素
for y in range(0, 13):
    print('y=%2d ' % y + ' '.join('%3d' % rows[y][x][0] for x in range(60, 100, 2)))
