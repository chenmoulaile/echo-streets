import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
def load(n):
    w,h,R = read_png(S % n); return w,h,R

# 02_back 顶部暗带 = 哪根梁？验证 y 投影
import math
F=175.9; CY=135.0
cam_y=1.7; cam_z=-14.0
for zl in (-17.25,-11.5,-5.75):
    d = zl-cam_z
    for wy in (3.47,3.56):
        sy = CY - (wy-cam_y)*F/d
        print('梁 z=%.2f 面 y=%.2f  dist=%.2f  sy=%.1f' % (zl,wy,d,sy))
print()
# 天花
for d in (2.5,3.0,4.0,6.0):
    print('天花 dist=%.1f  sy=%.1f' % (d, CY-(3.6-cam_y)*F/d))

print()
print('=== 00_player 纵向梁穿过灯槽验证（投影）===')
cam_z=18.0; cam_y=1.6
for xl in (-3.667,3.667):
    for d in (6.5,12.0,18.0):
        sx = 240 + xl*F/d
        print(' 纵梁 x=%.3f dist=%.1f -> sx=%.0f' % (xl,d,sx))

print()
print('=== 灯槽发光面 vs 槽底：UV 与像素 ===')
w,h,R = load('ch01_00_player')
print('  灯槽暗框行 y=54..58 mean:', ['%.3f'%(sum(lum(*R[y][x]) for x in range(84,160))/76/255) for y in range(54,59)])
print('  灯芯行   y=60..63 mean:', ['%.3f'%(sum(lum(*R[y][x]) for x in range(84,160))/76/255) for y in range(60,64)])
