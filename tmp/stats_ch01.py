import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

FILES = ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
         'ch01_03_right', 'ch01_04_left', 'ch01_05_top']

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

for f in FILES:
    p = r'D:\mygame\tmp\shots\chapter\%s.png' % f
    w, h, rows = read_png(p)
    vals = []
    hi = 0
    lo = 0
    for y in range(h):
        for x in range(w):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            vals.append(L)
            if L >= 250: hi += 1
            if L < 38: lo += 1
    n = len(vals)
    vals.sort()
    print('== %s  n=%d' % (f, n))
    print('  mean=%.1f  p1=%.1f p5=%.1f p50=%.1f p95=%.1f max=%.1f' % (
        sum(vals)/n, vals[n//100], vals[n//20], vals[n//2], vals[n*95//100], vals[-1]))
    print('  clip>=250: %.1f%%   dark<38: %.1f%%' % (100.0*hi/n, 100.0*lo/n))
