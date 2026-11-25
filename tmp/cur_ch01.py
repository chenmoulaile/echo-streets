import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
import math

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

w,h,R = read_png(S % 'ch01_00_player')
w1,h1,R1 = read_png(S % 'ch01_01_center')
w3,h3,R3 = read_png(S % 'ch01_03_right')
w4,h4,R4 = read_png(S % 'ch01_04_left')
w5,h5,R5 = read_png(S % 'ch01_05_top')
w2,h2,R2 = read_png(S % 'ch01_02_back')

print('### 1. 00_player 天花横向剖面 y=30/45/60/75 (x 步长 10) —— 找中轴灯带')
for y in [30, 45, 60, 75, 90]:
    print('  y=%3d %s' % (y, ' '.join('%3.0f' % lum(*R[y][x]) for x in range(10, 471, 10))))

print()
print('### 2. 中轴是否残留灯带：x=230..250 各列纵向均值（y=8..100）')
for x in range(228, 254, 2):
    col = [lum(*R[y][x]) for y in range(8, 101)]
    print('  x=%3d mean=%5.1f max=%5.1f' % (x, sum(col)/len(col), max(col)))

print()
print('### 3. 天花格栅梁定位：y=78..86 各行的全宽暗段')
for y in range(76, 90):
    seg = [lum(*R[y][x]) for x in range(8, 472)]
    dark = [i+8 for i,v in enumerate(seg) if v < 100]
    # 归并连续段
    runs = []
    if dark:
        s = dark[0]; p = dark[0]
        for x in dark[1:]:
            if x - p > 1:
                runs.append((s, p)); s = x
            p = x
        runs.append((s, p))
    print('  y=%3d mean=%5.1f 暗段(%d): %s' % (y, sum(seg)/len(seg), len(runs), runs[:8]))

print()
print('### 4. 天花板亮度 vs 地板亮度（判定明暗关系）')
def reg(R_, x0,y0,x1,y1):
    n=0;s=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            s+=lum(*R_[y][x]); n+=1
    return s/n
print('  00 天花中央区 (x=150..330,y=20..60) = %.3f' % (reg(R,150,20,330,60)/255))
print('  00 天花近处   (x=60..420,y=8..25)  = %.3f' % (reg(R,60,8,420,25)/255))
print('  00 地板近处   (x=60..420,y=235..262)= %.3f' % (reg(R,60,235,420,262)/255))
print('  00 地板上半   (x=60..420,y=200..235)= %.3f' % (reg(R,60,200,420,235)/255))
print('  01 天花 (x=100..380,y=20..70)      = %.3f' % (reg(R1,100,20,380,70)/255))
print('  01 地板 (x=100..380,y=200..262)    = %.3f' % (reg(R1,100,200,380,262)/255))

print()
print('### 5. 03_right 墙面取样（当前批次）')
for (x0,y0,x1,y1,lab) in [(150,40,330,90,'wall upper'),(150,100,330,150,'wall mid'),
                          (150,170,330,200,'wall low'),(20,120,70,190,'vending A'),
                          (265,110,320,200,'vending C'),(200,230,400,262,'floor'),
                          (150,205,330,222,'skirting')]:
    n=0;s=0;mn=999;mx=-1;dk=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            L=lum(*R3[y][x]); s+=L; n+=1
            if L<mn: mn=L
            if L>mx: mx=L
            if L<38: dk+=1
    print('  %-12s mean=%5.1f(%.3f) min=%5.1f max=%5.1f dark=%.1f%%' % (lab, s/n, s/n/255, mn, mx, 100.0*dk/n))

print()
print('### 6. 03_right 墙脚死黑逐行')
for y in range(200, 235, 2):
    seg = [lum(*R3[y][x]) for x in range(8, 472)]
    dk = sum(1 for v in seg if v < 38)
    print('  y=%3d mean=%5.1f min=%5.1f dark<38=%.1f%%' % (y, sum(seg)/len(seg), min(seg), 100.0*dk/len(seg)))

print()
print('### 7. 04_left 天空板逐窗格（当前批次）')
for i,(a,b) in enumerate([(20,80),(100,160),(180,240),(260,320),(340,400)]):
    n=0;s=0;sr=sg=sb=0
    for y in range(60,150):
        for x in range(a,b):
            r,g,bb = R4[y][x]; sr+=r;sg+=g;sb+=bb; n+=1
    print('  pane%d x=%d..%d rgb=(%.0f,%.0f,%.0f) lum=%.3f' % (i+1,a,b,sr/n,sg/n,sb/n,(0.299*sr+0.587*sg+0.114*sb)/n/255))

print()
print('### 8. 04_left 蓝裙与天空交界逐行（x=200）')
for y in range(150, 200, 2):
    print('  y=%3d rgb=%s lum=%5.1f' % (y, R4[y][200], lum(*R4[y][200])))

print()
print('### 9. 05_top 上部纯黑占比（当前批次）')
for y in range(8, 120, 6):
    seg = [R5[y][x] for x in range(8, 472)]
    blk = sum(1 for p in seg if p==(0,0,0))
    print('  y=%3d 纯黑=%5.1f%% mean_lum=%5.1f' % (y, 100.0*blk/len(seg), sum(lum(*p) for p in seg)/len(seg)))

print()
print('### 10. 02_back 远端（+Z 出生点方向）是否有视觉元素')
for (x0,y0,x1,y1,lab) in [(150,100,330,150,'far wall center'),(0,80,120,180,'left near'),
                          (360,80,479,180,'right near')]:
    n=0;s=0;mn=999;mx=-1
    for y in range(y0,y1):
        for x in range(x0,x1):
            L=lum(*R2[y][x]); s+=L;n+=1
            if L<mn:mn=L
            if L>mx:mx=L
    print('  %-16s mean=%5.1f(%.3f) min=%5.1f max=%5.1f' % (lab, s/n, s/n/255, mn, mx))
