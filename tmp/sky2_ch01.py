import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

# 1) SkyTexture.png 的 v 分布（与 Sunset 对比，找可替代图）
for name in ['SkyTexture', 'SkyTexture_Sunset']:
    w, h, rows = read_png(r'D:\mygame\assets\materials\%s.png' % name)
    print('== %s %dx%d' % (name, w, h))
    for y in range(0, h, 60):
        sr = sg = sb = 0; n = 0
        for x in range(0, w, 30):
            r, g, b = rows[y][x]
            sr += r; sg += g; sb += b; n += 1
        print('   v=%.3f  #%02X%02X%02X  lum=%.2f' % (
            y/h, sr//n, sg//n, sb//n, lum(sr/n, sg/n, sb/n)/255))

# 2) 柱础 / 踢脚线 实际亮度取样
def box(f, x0, y0, x1, y1, label):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    n = 0; s = 0.0; sr = sg = sb = 0; mn = 999; mx = -1
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            s += L; n += 1; mn = min(mn, L); mx = max(mx, L)
            sr += r; sg += g; sb += b
    print('   %-14s %-30s mean=%3.0f(%.3f) rgb=(%3d,%3d,%3d) range=%.0f..%.0f' % (
        f, label, s/n, s/n/255.0, sr//n, sg//n, sb//n, mn, mx))

box('ch01_05_top', 190, 60, 215, 90, 'column plinth (top view)')
box('ch01_05_top', 240, 190, 275, 215, 'column shaft white')
box('ch01_00_player', 92, 150, 108, 165, 'column plinth (spawn)')
box('ch01_03_right', 0, 170, 480, 180, 'right skirting strip')
box('ch01_00_player', 190, 235, 290, 250, 'center guidance band')
box('ch01_00_player', 60, 235, 170, 250, 'white floor same depth')
box('ch01_05_top', 150, 30, 200, 55, 'ceiling light slot (top)')
box('ch01_00_player', 200, 20, 280, 40, 'light strip surface')
