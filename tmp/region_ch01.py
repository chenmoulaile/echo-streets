import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def region(rows, x0, y0, x1, y1, label):
    n = 0; s = 0.0; mx = 0.0; mn = 255.0
    sr = sg = sb = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            s += L; n += 1; mx = max(mx, L); mn = min(mn, L)
            sr += r; sg += g; sb += b
    print('  %-26s mean=%.1f (%.3f) min=%.0f max=%.0f  rgb=(%d,%d,%d)' % (
        label, s/n, s/n/255.0, mn, mx, sr//n, sg//n, sb//n))

def run(f, regions):
    p = r'D:\mygame\tmp\shots\chapter\%s.png' % f
    w, h, rows = read_png(p)
    print('==', f, w, h)
    for r in regions:
        region(rows, *r[:4], label=r[4])

run('ch01_00_player', [
    (0, 0, 480, 40, 'top ceiling band'),
    (180, 0, 300, 30, 'ceiling center strip'),
    (150, 60, 330, 100, 'ceiling mid'),
    (0, 60, 90, 120, 'left sky/glass'),
    (390, 60, 480, 120, 'right wall upper'),
    (180, 200, 300, 260, 'floor center dark band'),
    (60, 200, 170, 260, 'floor left white'),
    (205, 105, 275, 145, 'far end reception'),
])
run('ch01_01_center', [
    (0, 0, 480, 30, 'ceiling band'),
    (150, 40, 330, 80, 'ceiling mid'),
    (200, 90, 280, 120, 'reception zone'),
    (100, 200, 200, 260, 'floor left'),
    (220, 200, 260, 260, 'floor center band'),
])
run('ch01_03_right', [
    (0, 0, 480, 60, 'wall upper'),
    (100, 60, 380, 140, 'wall mid'),
    (0, 160, 480, 200, 'wall low'),
    (60, 60, 130, 160, 'vending machine A'),
    (250, 60, 340, 200, 'vending machine B'),
    (380, 60, 470, 200, 'vending machine C'),
    (0, 210, 480, 270, 'floor'),
])
run('ch01_04_left', [
    (0, 0, 480, 30, 'ceiling'),
    (0, 30, 480, 140, 'sky through glass'),
    (0, 140, 480, 190, 'blue skirting'),
    (0, 200, 480, 270, 'floor'),
    (440, 30, 480, 190, 'right edge glass'),
])
run('ch01_05_top', [
    (0, 0, 480, 40, 'top edge'),
    (0, 40, 100, 200, 'left sky band'),
    (150, 100, 330, 220, 'floor center'),
    (380, 0, 480, 120, 'right dark corner'),
])
