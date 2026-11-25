import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

FILES = ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
         'ch01_03_right', 'ch01_04_left', 'ch01_05_top']
BORDER = 8  # 排除 CRT 曲率黑边

def inside(x, y, w, h):
    return BORDER <= x < w-BORDER and BORDER <= y < h-BORDER

print('### CLIP >=250 (排除 CRT 黑边)')
for f in FILES:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    d = {}
    tot = 0
    n = 0
    for y in range(h):
        for x in range(w):
            if not inside(x, y, w, h):
                continue
            n += 1
            L = lum(*rows[y][x])
            if L >= 250:
                tot += 1
                d.setdefault((y//15)*15, []).append(x)
    print('== %-16s clip=%.1f%% of %d px' % (f, 100.0*tot/n, n))
    for k in sorted(d):
        v = d[k]
        if len(v) < 100:
            continue
        print('   y=%3d-%3d n=%5d x=%3d..%3d' % (k, k+14, len(v), min(v), max(v)))

print()
print('### DARK <38 (排除 CRT 黑边)')
for f in FILES:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    d = {}
    tot = 0
    n = 0
    for y in range(h):
        for x in range(w):
            if not inside(x, y, w, h):
                continue
            n += 1
            L = lum(*rows[y][x])
            if L < 38:
                tot += 1
                d.setdefault((y//15)*15, []).append(x)
    print('== %-16s dark=%.1f%% of %d px' % (f, 100.0*tot/n, n))
    for k in sorted(d):
        v = d[k]
        if len(v) < 120:
            continue
        print('   y=%3d-%3d n=%5d x=%3d..%3d' % (k, k+14, len(v), min(v), max(v)))
