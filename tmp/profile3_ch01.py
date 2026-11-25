import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def row(f, y, x0=0, x1=480, step=8):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    out = []
    for x in range(x0, x1, step):
        r, g, b = rows[y][x]
        out.append('%d:%d' % (x, int(lum(r, g, b))))
    print('-- %s y=%d' % (f, y))
    print('   ' + ' '.join(out))

def col(f, x, y0=0, y1=270, step=4):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    out = []
    for y in range(y0, y1, step):
        r, g, b = rows[y][x]
        out.append('%d:%d' % (y, int(lum(r, g, b))))
    print('-- %s x=%d' % (f, x))
    print('   ' + ' '.join(out))

row('ch01_05_top', 4, 0, 480, 10)
row('ch01_05_top', 30, 0, 480, 10)
col('ch01_05_top', 460, 0, 120, 4)
# 柱顶压条：出生点画面里最近的柱子顶部
col('ch01_00_player', 120, 80, 200, 4)
col('ch01_00_player', 355, 80, 200, 4)
