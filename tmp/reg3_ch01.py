import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

D = r'D:\mygame\tmp\shots\chapter\%s.png'
FILES = ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
         'ch01_03_right', 'ch01_04_left', 'ch01_05_top']

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def region(rows, x0, y0, x1, y1):
    n = 0; s = 0; mn = 999; mx = -1; sr = sg = sb = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            s += L; n += 1; sr += r; sg += g; sb += b
            if L < mn: mn = L
            if L > mx: mx = L
    return (s/n, mn, mx, (sr/n, sg/n, sb/n))

R = {
 'ch01_00_player': [
   ('ceiling far band',      150, 40, 330, 60),
   ('ceiling mid band',      150, 60, 330, 85),
   ('ceiling near top',      150, 15, 330, 40),
   ('floor center band',     200, 200, 280, 250),
   ('floor left white',      60, 200, 150, 250),
   ('floor right white',     330, 200, 420, 250),
   ('right wall upper',      400, 90, 470, 120),
   ('left sky',              20, 100, 110, 150),
   ('blue skirting',         20, 150, 110, 165),
   ('far reception',         200, 120, 280, 140),
   ('col left body',         95, 110, 120, 160),
   ('col base',              95, 158, 120, 168),
 ],
 'ch01_01_center': [
   ('ceiling strip',         220, 30, 260, 90),
   ('ceiling mid',           120, 40, 200, 90),
   ('floor left',            60, 180, 180, 250),
   ('floor center band',     210, 180, 270, 250),
   ('reception zone',        190, 120, 290, 150),
   ('right wall',            400, 100, 470, 150),
 ],
 'ch01_03_right': [
   ('wall upper',            150, 40, 330, 90),
   ('wall mid',              150, 100, 330, 150),
   ('wall low',              150, 160, 330, 200),
   ('vending A',             20, 120, 70, 190),
   ('vending B',             100, 120, 150, 190),
   ('vending C',             265, 110, 320, 200),
   ('floor',                 200, 230, 400, 265),
   ('skirting line',         150, 205, 330, 215),
 ],
 'ch01_04_left': [
   ('ceiling',               150, 20, 330, 60),
   ('sky pane 1',            20, 60, 90, 150),
   ('sky pane 2',            95, 60, 165, 150),
   ('blue skirting',         60, 165, 400, 195),
   ('floor',                 150, 220, 330, 262),
   ('mullion',               88, 70, 96, 150),
 ],
 'ch01_05_top': [
   ('top edge',              8, 8, 471, 25),
   ('upper mid',             8, 30, 471, 80),
   ('floor center',          150, 150, 330, 220),
   ('right dark corner',     400, 30, 470, 80),
   ('left sky band',         20, 30, 120, 90),
   ('bottom edge',           8, 245, 471, 262),
 ],
}

for f in FILES:
    if f not in R:
        continue
    w, h, rows = read_png(D % f)
    print('===== %s' % f)
    for name, x0, y0, x1, y1 in R[f]:
        m, mn, mx, rgb = region(rows, x0, y0, x1, y1)
        print('  %-20s mean=%6.1f (%5.3f) min=%5.1f max=%5.1f rgb=(%3.0f,%3.0f,%3.0f)'
              % (name, m, m/255.0, mn, mx, rgb[0], rgb[1], rgb[2]))
