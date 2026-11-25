import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
def load(n):
    w,h,R = read_png(S % n); return w,h,R

w,h,R = load('ch01_00_player')
print('=== 00_player x=240 y=155..205 原始序列 ===')
for y in range(155,206):
    print('  y=%3d rgb%-16s lum=%.3f' % (y,str(R[y][240]),lum(*R[y][240])/255))

print()
print('=== 00_player x=200 y=155..205（带外白砖）===')
for y in range(155,206,3):
    print('  y=%3d rgb%-16s lum=%.3f' % (y,str(R[y][200]),lum(*R[y][200])/255))

print()
print('=== 00_player 横向 y=190 跨带剖面 x=180..300 ===')
for x in range(180,302,4):
    print('  x=%3d rgb%-16s lum=%.3f' % (x,str(R[190][x]),lum(*R[190][x])/255))
