import sys
sys.path.insert(0, r'D:\mygame\tmp')
import probe_ch01_px
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

p = r'D:\mygame\tmp\shots\chapter\ch01_00_player.png'
w, h, rows = read_png(p)
print('dims', w, h, len(rows), len(rows[0]))
# 方式 A：直接索引
vals = []
for y in range(h):
    for x in range(w):
        r, g, b = rows[y][x]
        vals.append(0.299*r + 0.587*g + 0.114*b)
vals.sort()
n = len(vals)
print('A  mean=%.1f p50=%.1f p95=%.1f max=%.1f  >=250=%.2f%%' % (
    sum(vals)/n, vals[n//2], vals[n*95//100], vals[-1],
    100.0*sum(1 for v in vals if v >= 250)/n))

# 方式 B：lum(*px)
vals2 = []
for y in range(h):
    for x in range(w):
        vals2.append(lum(*rows[y][x]))
vals2.sort()
print('B  mean=%.1f p50=%.1f p95=%.1f max=%.1f  >=250=%.2f%%' % (
    sum(vals2)/n, vals2[n//2], vals2[n*95//100], vals2[-1],
    100.0*sum(1 for v in vals2 if v >= 250)/n))

# 抽样 20 个点打印
import random
random.seed(1)
for _ in range(10):
    x = random.randrange(w); y = random.randrange(h)
    print('  (%d,%d)=%s lum=%.1f' % (x, y, rows[y][x], lum(*rows[y][x])))
print('read_png source file:', probe_ch01_px.__file__)
