import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

FILES = ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
         'ch01_03_right', 'ch01_04_left', 'ch01_05_top']
for f in FILES:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    vals = []
    n240 = 0
    n250 = 0
    n255 = 0
    for y in range(h):
        for x in range(w):
            L = lum(*rows[y][x])
            vals.append(L)
            if L > 240: n240 += 1
            if L >= 250: n250 += 1
            if min(rows[y][x]) >= 255: n255 += 1
    vals.sort()
    n = len(vals)
    print('%-16s n=%d mean=%.1f p50=%.1f p95=%.1f p99=%.1f max=%.1f  >240=%.2f%%  >=250=%.2f%%  all255=%.3f%%' % (
        f, n, sum(vals)/n, vals[n//2], vals[n*95//100], vals[n*99//100], vals[-1],
        100.0*n240/n, 100.0*n250/n, 100.0*n255/n))
