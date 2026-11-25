import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def bands(f, thresh=30):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    print('== %s  lum<%d clusters (10px rows)' % (f, thresh))
    d = {}
    for y in range(h):
        for x in range(w):
            r, g, b = rows[y][x]
            if lum(r, g, b) < thresh:
                d.setdefault((y // 10) * 10, []).append((x, y, r, g, b))
    for k in sorted(d):
        pts = d[k]
        if len(pts) < 40:
            continue
        xs = [p[0] for p in pts]
        rs = sum(p[2] for p in pts)/len(pts)
        gs = sum(p[3] for p in pts)/len(pts)
        bs = sum(p[4] for p in pts)/len(pts)
        print('   y=%3d-%3d n=%4d x=%3d..%3d rgb=(%3.0f,%3.0f,%3.0f)' % (
            k, k+9, len(pts), min(xs), max(xs), rs, gs, bs))

for f in ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
          'ch01_03_right', 'ch01_04_left', 'ch01_05_top']:
    bands(f)
