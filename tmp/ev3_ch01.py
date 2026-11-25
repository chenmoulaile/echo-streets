import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'
M = r'D:\mygame\assets\materials\%s.png'

print('### 1. sky_window.png 尺寸')
w,h,_ = read_png(M % 'sky_window')
print('  %dx%d  ratio=%.2f:1' % (w, h, w/h))

print()
print('### 2. 中轴灯带中央暗线精确宽度（00_player y=52 与 y=110 横剖 x=225..255）')
ww,hh,rows = read_png(S % 'ch01_00_player')
for y in [52, 53, 110, 111, 112]:
    vals = [(x, lum(*rows[y][x])) for x in range(228, 254)]
    print('  y=%3d  %s' % (y, ' '.join('%d:%.0f' % (x, v) for x, v in vals)))

print()
print('### 3. 灯槽 vs 格栅梁几何冲突核算')
print('  ceiling_grid axis=z step=4.0 across=22 count=round(22/4)=6')
print('  梁 x 位置 = -11 + 22*i/6, i=0..6 =', [round(-11 + 22*i/6, 3) for i in range(7)])
print('  梁宽 0.10 -> 覆盖 x =', [(round(-11+22*i/6-0.05,3), round(-11+22*i/6+0.05,3)) for i in range(7)])
print('  灯槽 x=±3.0 宽 1.9 -> 覆盖 [2.05,3.95] / [-3.95,-2.05]')
print('  梁 x=3.667 覆盖 [3.617,3.717] -> 完全落在灯槽内部')
print('  中轴灯槽 x=0 宽 0.5 -> 覆盖 [-0.25,0.25]；梁 x=0 覆盖 [-0.05,0.05] -> 完全落在内部')
print('  Y 层：梁 center=H-0.04=3.56 drop=0.09 -> [3.515,3.605]')
print('        灯槽 center=H-0.045=3.555 h=0.09 -> [3.510,3.600] -> 同区间，实体相交')

print()
print('### 4. 售货机/储物柜/踢脚线与墙共面核算')
print('  墙 panel x=HALF_W=11.0')
print('  售货机 x=10.64 size.x=0.72 -> [10.28,11.00]  背面 x=11.00 与墙共面')
print('  储物柜 x=10.74 size.x=0.52 -> [10.48,11.00]  背面 x=11.00 与墙共面')
print('  踢脚线 x=10.95 size.x=0.10 -> [10.90,11.00]  背面 x=11.00 与墙共面')

print()
print('### 5. 前台在 00_player 屏幕尺寸核算')
import math
fov_v = 75.0
dist = 18.0 - (-22.84)
print('  机位 z=18, 门 z=-22.84, 距离=%.2f 米' % dist)
px_per_m = 270.0 / (2*dist*math.tan(math.radians(fov_v/2)))
print('  垂直: %.2f px/米 -> 门高 2.3 米 = %.1f px' % (px_per_m, 2.3*px_per_m))
fov_h = 2*math.degrees(math.atan(math.tan(math.radians(fov_v/2))*480/270))
px_per_m_h = 480.0 / (2*dist*math.tan(math.radians(fov_h/2)))
print('  水平: %.2f px/米 -> 门宽 3.2 米 = %.1f px' % (px_per_m_h, 3.2*px_per_m_h))
print('  前台台面 7.3 米 = %.1f px 宽' % (7.3*px_per_m_h))

print()
print('### 6. 05_top 机位越界核算')
print('  机位 = start(0,0,18) + (0,6.5,6) = (0,6.5,24)')
print('  房间 z ∈ [-23,23]  -> z=24 在墙外 1.0 米')
print('  净高 H=3.6        -> y=6.5 在天花上方 2.9 米')
print('  天花 panel 法线 -Y，从上方看为背面 -> CULL')

print()
print('### 7. 灯下/两灯间/中轴 实测（最新批次）')
for f, y in [('ch01_00_player', 240)]:
    pass
w0,h0,r0 = read_png(S % 'ch01_00_player')
def pt(x,y):
    return lum(*r0[y][x])
print('  地板 x=200 y=250 (中轴带) = %.3f' % (pt(200,250)/255))
print('  地板 x=120 y=250 (白砖)   = %.3f' % (pt(120,250)/255))
print('  天花 x=200 y=30 (近)      = %.3f' % (pt(200,30)/255))
print('  天花 x=200 y=70 (中)      = %.3f' % (pt(200,70)/255))
print('  柱身 x=105 y=120          = %.3f' % (pt(105,120)/255))
print('  柱础 x=105 y=165          = %.3f' % (pt(105,165)/255))

print()
print('### 8. 03_right 墙面是否含任何可辨纹理（方差/梯度）')
w3,h3,r3 = read_png(S % 'ch01_03_right')
vals = []
for y in range(50, 150):
    for x in range(150, 330):
        vals.append(lum(*r3[y][x]))
n = len(vals)
mean = sum(vals)/n
var = sum((v-mean)**2 for v in vals)/n
print('  墙面 x=150..330 y=50..150  mean=%.1f sd=%.2f  range=%.0f..%.0f' % (
    mean, var**0.5, min(vals), max(vals)))
# 水平梯度
g = 0; cnt = 0
for y in range(50, 150):
    for x in range(150, 329):
        g += abs(lum(*r3[y][x+1]) - lum(*r3[y][x])); cnt += 1
print('  水平相邻像素平均差 = %.2f/255' % (g/cnt))
g = 0; cnt = 0
for y in range(50, 149):
    for x in range(150, 330):
        g += abs(lum(*r3[y+1][x]) - lum(*r3[y][x])); cnt += 1
print('  垂直相邻像素平均差 = %.2f/255' % (g/cnt))
