import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def prof(f, y0, y1, x0, x1, step, label):
    p = r'D:\mygame\tmp\shots\chapter\%s.png' % f
    w, h, rows = read_png(p)
    print('-- %s %s  y[%d:%d] x[%d:%d]' % (f, label, y0, y1, x0, x1))
    out = []
    for x in range(x0, x1, step):
        s = 0.0; n = 0
        for y in range(y0, y1):
            r, g, b = rows[y][x]
            s += lum(r, g, b); n += 1
        out.append((x, s/n))
    print('   ' + ' '.join('%d:%.0f' % (x, v) for x, v in out))

def box(f, x0, y0, x1, y1, label):
    p = r'D:\mygame\tmp\shots\chapter\%s.png' % f
    w, h, rows = read_png(p)
    n = 0; s = 0.0; sr = sg = sb = 0; mn = 999; mx = -1
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            s += L; n += 1; mn = min(mn, L); mx = max(mx, L)
            sr += r; sg += g; sb += b
    print('   %-30s %s mean=%.0f(%.3f) rgb=(%d,%d,%d) range=%.0f..%.0f' % (
        f, label, s/n, s/n/255.0, sr//n, sg//n, sb//n, mn, mx))

prof('ch01_01_center', 2, 16, 0, 480, 12, 'ceiling top slice')
prof('ch01_00_player', 2, 14, 0, 480, 12, 'ceiling top slice')
prof('ch01_02_back', 130, 160, 60, 420, 24, 'floor-wall joint (back wall)')
box('ch01_02_back', 150, 128, 330, 140, 'back wall lower')
box('ch01_02_back', 150, 140, 330, 152, 'floor near joint')
box('ch01_04_left', 40, 150, 440, 168, 'blue skirting band')
box('ch01_04_left', 40, 172, 440, 200, 'floor front')
box('ch01_01_center', 210, 4, 270, 30, 'ceiling axis strip')
box('ch01_01_center', 120, 4, 180, 30, 'ceiling left of axis')
box('ch01_01_center', 300, 4, 360, 30, 'ceiling right of axis')
box('ch01_00_player', 215, 0, 265, 20, 'ceiling axis strip (spawn)')
box('ch01_00_player', 100, 0, 180, 20, 'ceiling left (spawn)')
