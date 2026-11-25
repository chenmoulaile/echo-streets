import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def hotspots(f, thresh=38, topn=8):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    print('== %s dark<%.0f hotspots' % (f, thresh))
    scored = []
    for y in range(h):
        c = 0; s = 0.0
        for x in range(w):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            if L < thresh:
                c += 1
            s += L
        scored.append((c, y, s/w))
    scored.sort(reverse=True)
    for c, y, m in scored[:topn]:
        # 找该行最暗的连续 x 段
        best = None; run_start = None
        for x in range(w):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            if L < thresh:
                if run_start is None:
                    run_start = x
            else:
                if run_start is not None:
                    if best is None or x-run_start > best[1]-best[0]:
                        best = (run_start, x)
                    run_start = None
        if run_start is not None and (best is None or w-run_start > best[1]-best[0]):
            best = (run_start, w)
        print('   y=%3d darkpx=%3d rowmean=%.0f  widest dark run x=%s' % (
            y, c, m, best))

def hist(f, x0, y0, x1, y1, label, nb=12):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    vals = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            vals.append(lum(r, g, b))
    vals.sort()
    print('-- %s %s  n=%d  min=%.0f max=%.0f' % (f, label, len(vals), vals[0], vals[-1]))
    lo, hi = vals[0], vals[-1]
    step = (hi - lo) / nb if hi > lo else 1
    buckets = [0]*nb
    for v in vals:
        i = min(int((v-lo)/step), nb-1) if step else 0
        buckets[i] += 1
    tot = len(vals)
    for i, c in enumerate(buckets):
        a = lo + i*step
        print('   %6.1f..%6.1f  %5.1f%%  %s' % (a, a+step, 100.0*c/tot, '#'*int(60.0*c/tot)))

hotspots('ch01_03_right')
hotspots('ch01_05_top')
hist('ch01_03_right', 100, 40, 380, 140, 'right wall flat area')
hist('ch01_00_player', 40, 200, 180, 260, 'floor left white area')
