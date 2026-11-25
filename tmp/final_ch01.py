import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def stat(path, x0=0, y0=0, x1=None, y1=None, label=''):
    w, h, rows = read_png(path)
    if x1 is None: x1 = w
    if y1 is None: y1 = h
    n=0; s=0; mn=999; mx=-1; sr=sg=sb=0; dark=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            r,g,b = rows[y][x]
            L = lum(r,g,b); s+=L; n+=1; sr+=r; sg+=g; sb+=b
            if L<mn: mn=L
            if L>mx: mx=L
            if L<38: dark+=1
    print('  %-22s mean=%6.1f (%5.3f) min=%5.1f max=%5.1f rgb=(%3.0f,%3.0f,%3.0f) dark<38=%.1f%%'
          % (label, s/n, s/n/255.0, mn, mx, sr/n, sg/n, sb/n, 100.0*dark/n))

print('### sky_window.png 原图')
stat(r'D:\mygame\assets\materials\sky_window.png', label='sky_window full')

print('### 材质原始均值对照')
for m in ['MetalWall', 'CeramicFloor_Gray', 'sky_window', 'WhiteWall']:
    stat(r'D:\mygame\assets\materials\%s.png' % m, label=m)

S = r'D:\mygame\tmp\shots\chapter\%s.png'
print('### 柱础（00_player）逐行')
w,h,rows = read_png(S % 'ch01_00_player')
for y in range(155, 172):
    vals = [lum(*rows[y][x]) for x in range(96, 122)]
    print('  y=%3d mean=%5.1f min=%5.1f  %s' % (y, sum(vals)/len(vals), min(vals),
          ' '.join('%3.0f' % v for v in vals)))

print('### 天花板格栅梁（00_player y=80 横剖面 x=150..330）')
for y in [78, 79, 80, 81, 82, 83, 84, 85]:
    vals = [lum(*rows[y][x]) for x in range(150, 331, 5)]
    print('  y=%3d mean=%5.1f  %s' % (y, sum(vals)/len(vals), ' '.join('%3.0f' % v for v in vals)))

print('### 幕墙竖挺（04_left）x=80..100, y=80..150 逐列')
w4,h4,r4 = read_png(S % 'ch01_04_left')
for x in range(78, 104):
    vals = [lum(*r4[y][x]) for y in range(80, 150)]
    print('  x=%3d mean=%5.1f min=%5.1f max=%5.1f' % (x, sum(vals)/len(vals), min(vals), max(vals)))

print('### 天空板取样（04_left 各窗格中心）')
for i,(a,b) in enumerate([(15,70),(105,160),(190,245),(275,330),(360,415)]):
    stat(S % 'ch01_04_left', a, 70, b, 140, label='pane %d x=%d..%d' % (i+1, a, b))
