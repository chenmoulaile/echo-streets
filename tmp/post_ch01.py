import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
from crop_ch01 import write_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

# A) WhiteCeiling_MetalEdge 放大 + 行/列剖面，找黑带
w, h, rows = read_png(r'D:\mygame\assets\materials\WhiteCeiling_MetalEdge.png')
print('WhiteCeiling_MetalEdge %dx%d' % (w, h))
big = []
for y in range(h):
    line = []
    for x in range(w):
        line.extend([rows[y][x]] * 3)
    big.extend([line] * 3)
write_png(r'D:\mygame\tmp\mat_MetalEdge.png', big)
print('  col profile (x, mean lum over y):')
out = []
for x in range(0, w, 5):
    s = sum(lum(*rows[y][x]) for y in range(h)) / h
    out.append('%d:%.0f' % (x, s))
print('   ' + ' '.join(out))
print('  row profile (y, mean lum over x):')
out = []
for y in range(0, h, 5):
    s = sum(lum(*rows[y][x]) for x in range(w)) / w
    out.append('%d:%.0f' % (y, s))
print('   ' + ' '.join(out))

# B) 扫描线：右墙平坦区相邻行均值
for f in ['ch01_03_right', 'ch01_04_left', 'ch01_02_back']:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    print('== %s adjacent-row delta on flat patch x=150..330' % f)
    out = []
    for y in range(100, 120):
        s = sum(lum(*rows[y][x]) for x in range(150, 330)) / 180.0
        out.append('%d:%.1f' % (y, s))
    print('   ' + ' '.join(out))

# C) 色差：竖直强边缘的 R/G/B 三通道错位
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\ch01_00_player.png')
print('== ch01_00_player 竖直边缘 (柱边) 通道分离 y=120')
for y in [110, 120, 130]:
    seg = []
    for x in range(100, 125):
        r, g, b = rows[y][x]
        seg.append('%d:(%d,%d,%d)' % (x, r, g, b))
    print('   y=%d ' % y + ' '.join(seg))
