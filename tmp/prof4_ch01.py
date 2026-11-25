import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

w,h,rows = read_png(S % 'ch01_00_player')
print('### 中轴灯带纵向剖面 x=236..244（找横向黑线/格栅穿透）')
for y in range(30, 130, 1):
    vals = [lum(*rows[y][x]) for x in range(232, 250)]
    if min(vals) < 120:
        print('  y=%3d min=%5.1f  %s' % (y, min(vals), ' '.join('%3.0f' % v for v in vals)))

print()
print('### 左侧灯槽（x=150..175）纵向剖面，找格栅横穿')
for y in range(60, 100, 1):
    vals = [lum(*rows[y][x]) for x in range(148, 178)]
    print('  y=%3d mean=%5.1f min=%5.1f  %s' % (y, sum(vals)/len(vals), min(vals),
          ' '.join('%3.0f' % v for v in vals)))

print()
print('### 远端前台逐行（00_player x=205..275）')
for y in range(112, 140, 1):
    vals = [lum(*rows[y][x]) for x in range(205, 276)]
    print('  y=%3d mean=%5.1f min=%5.1f max=%5.1f' % (y, sum(vals)/len(vals), min(vals), max(vals)))

print()
print('### 右墙 x=420..470 逐行（03_right）')
w3,h3,r3 = read_png(S % 'ch01_03_right')
for y in range(20, 260, 10):
    vals = [lum(*r3[y][x]) for x in range(420, 471)]
    print('  y=%3d mean=%5.1f min=%5.1f max=%5.1f' % (y, sum(vals)/len(vals), min(vals), max(vals)))
