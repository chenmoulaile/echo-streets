import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

FILES = ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
         'ch01_03_right', 'ch01_04_left', 'ch01_05_top']

for f in FILES:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    # 四条边 8px 内的亮度
    def band(pts, label):
        v = [lum(*rows[y][x]) for x, y in pts]
        return '%s min=%.0f max=%.0f mean=%.0f' % (label, min(v), max(v), sum(v)/len(v))
    top = [(x, y) for y in range(0, 8) for x in range(0, w, 3)]
    bot = [(x, y) for y in range(h-8, h) for x in range(0, w, 3)]
    lef = [(x, y) for x in range(0, 8) for y in range(0, h, 3)]
    rig = [(x, y) for x in range(w-8, w) for y in range(0, h, 3)]
    print('== %s' % f)
    print('   ' + band(top, 'top8  '))
    print('   ' + band(bot, 'bot8  '))
    print('   ' + band(lef, 'left8 '))
    print('   ' + band(rig, 'right8'))
    # 中心 4 角
    for name, (x, y) in [('TL', (2, 2)), ('TR', (w-3, 2)),
                         ('BL', (2, h-3)), ('BR', (w-3, h-3))]:
        print('   %s=%s' % (name, rows[y][x]))
    # 中间行左右边缘逐像素
    mid = h // 2
    print('   mid row y=%d  x0..10: %s' % (
        mid, ' '.join('%d' % lum(*rows[mid][x]) for x in range(0, 11))))
    print('   mid row y=%d  x469..479: %s' % (
        mid, ' '.join('%d' % lum(*rows[mid][x]) for x in range(469, 480))))
