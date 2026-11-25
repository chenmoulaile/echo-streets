import sys, math
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b

def load(n):
    w,h,R = read_png(S % n); return w,h,R

# ---------- 1. 03_right 右墙纹理缺失定量 ----------
w,h,R = load('ch01_03_right')
print('=== ch01_03_right 右墙局部纹理强度（相邻像素|ΔL| 均值，0..255）===')
def gradd(R,x0,y0,x1,y1):
    s=0;n=0
    for y in range(y0,y1):
        for x in range(x0+1,x1):
            s+=abs(lum(*R[y][x])-lum(*R[y][x-1])); n+=1
    return s/n
for (x0,y0,x1,y1,lab) in [(150,60,400,140,'wall upper'),
                          (150,140,400,190,'wall mid'),
                          (60,60,140,190,'wall left'),
                          (300,200,440,240,'floor right')]:
    print('  %-14s meanGrad=%.2f  meanLum=%.1f' % (
        lab, gradd(R,x0,y0,x1,y1),
        sum(lum(*R[y][x]) for y in range(y0,y1) for x in range(x0,x1))/((y1-y0)*(x1-x0))))

print()
print('=== ch01_03_right 售货机几何（逐列找深色箱体）===')
y=110
row=[lum(*R[y][x]) for x in range(w)]
runs=[]; inr=False
for x in range(8,472):
    d = row[x]<80
    if d and not inr: st=x; inr=True
    elif not d and inr: runs.append((st,x-1)); inr=False
print('  y=110 暗段(<80):', runs)

print()
# ---------- 2. 04_left 每格天空 RGB ----------
w,h,R = load('ch01_04_left')
print('=== ch01_04_left 幕墙每格天空平均 RGB（y=60..150）===')
for i in range(8):
    x0 = 8 + i*58
    x1 = min(x0+50, 471)
    rs=gs=bs=0; n=0
    for y in range(60,150):
        for x in range(x0,x1):
            r,g,b = R[y][x]; rs+=r; gs+=g; bs+=b; n+=1
    print('  pane%d x=%3d..%3d  rgb(%3d,%3d,%3d)  lum=%.3f' % (
        i,x0,x1,rs//n,gs//n,bs//n,lum(rs//n,gs//n,bs//n)/255))

print()
print('=== ch01_04_left 蓝裙 vs 天空 分界（x=200 竖剖面）===')
for y in range(150,200,2):
    r,g,b=R[y][200]
    print('  y=%3d rgb(%3d,%3d,%3d) lum=%.3f' % (y,r,g,b,lum(r,g,b)/255))

print()
# ---------- 3. 05_top 上部黑区 ----------
w,h,R = load('ch01_05_top')
print('=== ch01_05_top 逐行纯黑/暗占比 ===')
for y in range(0,120,6):
    blk=sum(1 for x in range(8,472) if R[y][x][0]==0 and R[y][x][1]==0 and R[y][x][2]==0)
    dk =sum(1 for x in range(8,472) if lum(*R[y][x])<38)
    print('  y=%3d pure0=%5.1f%%  dark<38=%5.1f%%  meanLum=%.1f' % (
        y, 100.0*blk/464, 100.0*dk/464,
        sum(lum(*R[y][x]) for x in range(8,472))/464))

print()
# ---------- 4. 00_player 天花格栅梁条数与间距 ----------
w,h,R = load('ch01_00_player')
print('=== ch01_00_player x=150 竖剖面：找格栅梁（暗谷）===')
prev=None
for y in range(8,130):
    L=lum(*R[y][150])/255
    if L<0.30:
        print('  y=%3d lum=%.3f rgb%s  <== 暗梁' % (y,L,R[y][150]))

print()
print('=== ch01_01_center x=240 竖剖面 天花段 ===')
w2,h2,R2 = load('ch01_01_center')
for y in range(8,130,2):
    L=lum(*R2[y][240])/255
    mark = ' <== beam' if L<0.30 else ''
    print('  y=%3d lum=%.3f%s' % (y,L,mark))
