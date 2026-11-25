import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

w,h,R = read_png(S % 'ch01_00_player')
w1,h1,R1 = read_png(S % 'ch01_01_center')

def reg(R_, x0,y0,x1,y1):
    n=0;s=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            s+=lum(*R_[y][x]); n+=1
    return s/n/255

print('### 地板白砖（排除中轴带）')
for (x0,y0,x1,y1,lab) in [(60,235,140,262,'floor white near-L'),
                          (340,235,420,262,'floor white near-R'),
                          (60,200,140,235,'floor white mid-L'),
                          (340,200,420,235,'floor white mid-R'),
                          (200,235,280,262,'floor center band near'),
                          (200,200,280,235,'floor center band mid')]:
    print('  %-24s %.3f' % (lab, reg(R,x0,y0,x1,y1)))

print()
print('### 天花板')
for (x0,y0,x1,y1,lab) in [(60,8,420,25,'ceiling near top'),
                          (150,20,330,60,'ceiling center'),
                          (60,60,140,100,'ceiling left mid'),
                          (340,60,420,100,'ceiling right mid')]:
    print('  %-24s %.3f' % (lab, reg(R,x0,y0,x1,y1)))

print()
print('### 柱身/柱础')
for (x0,y0,x1,y1,lab) in [(95,110,120,158,'col body'),(96,162,122,169,'col base')]:
    print('  %-24s %.3f' % (lab, reg(R,x0,y0,x1,y1)))

print()
print('### 出生点脚下地板 vs 头顶天花（同一条竖线 x=240）')
for y in range(8, 262, 8):
    print('  y=%3d lum=%.3f' % (y, lum(*R[y][240])/255))

print()
print('### 灯 z 序列与出生点距离核算')
for z in [-19.0,-12.5,-6.0,0.5,7.0,13.5]:
    d = abs(18.0 - z)
    t = max(0.0, 1.0 - d/6.0)
    print('  z=%6.1f  距出生点(0,18) %.1f 米  atten=(1-d/6)^2=%.4f' % (z, d, t*t))

print()
print('### 01_center 天花 vs 地板（排除中轴）')
print('  ceiling (x=100..380,y=20..70)   %.3f' % reg(R1,100,20,380,70))
print('  floor white (x=60..180,y=200..262) %.3f' % reg(R1,60,180,180,262))
print('  floor white (x=300..420,y=200..262) %.3f' % reg(R1,300,180,420,262))
