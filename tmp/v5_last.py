import sys, math
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
def load(n):
    w,h,R = read_png(S % n); return w,h,R

# 1) 02_back 顶部
w,h,R = load('ch01_02_back')
print('=== 02_back 顶部逐行（x=8..471）===')
for y in range(0,32,2):
    vals=[lum(*R[y][x]) for x in range(8,472)]
    blk=sum(1 for x in range(8,472) if R[y][x][0]==0 and R[y][x][1]==0 and R[y][x][2]==0)
    print('  y=%2d mean=%6.1f pure0=%5.1f%% max=%5.1f' % (y,sum(vals)/len(vals),100.0*blk/464,max(vals)))

# 2) 03_right 墙面低频梯度（8x8 块平均后相邻块差）
w,h,R = load('ch01_03_right')
print()
print('=== 03_right 右墙低频梯度（8x8 块均值后相邻块 |Δ|）===')
def lowgrad(R,x0,y0,x1,y1,bs=8):
    bw=(x1-x0)//bs; bh=(y1-y0)//bs
    grid=[]
    for by in range(bh):
        row=[]
        for bx in range(bw):
            s=0
            for y in range(y0+by*bs,y0+by*bs+bs):
                for x in range(x0+bx*bs,x0+bx*bs+bs):
                    s+=lum(*R[y][x])
            row.append(s/(bs*bs))
        grid.append(row)
    hs=[];vs=[]
    for by in range(bh):
        for bx in range(bw-1):
            hs.append(abs(grid[by][bx+1]-grid[by][bx]))
    for by in range(bh-1):
        for bx in range(bw):
            vs.append(abs(grid[by+1][bx]-grid[by][bx]))
    allv=hs+vs
    return sum(allv)/len(allv), max(allv), sum(grid[by][bx] for by in range(bh) for bx in range(bw))/(bh*bw)

for x0,y0,x1,y1,lab in [(160,60,400,140,'wall upper'),(160,140,400,190,'wall mid'),(60,200,440,250,'floor')]:
    m,mx,avg = lowgrad(R,x0,y0,x1,y1)
    print('  %-12s lowGrad mean=%.2f max=%.2f blockAvg=%.1f' % (lab,m,mx,avg))

# 3) 00_player 天花：格栅梁条数与位置
w,h,R = load('ch01_00_player')
print()
print('=== 00_player 竖线 x=300 天花段暗谷（lum<0.45）===')
runs=[];inr=False
for y in range(8,140):
    d = lum(*R[y][300])/255 < 0.45
    if d and not inr: st=y;inr=True
    elif not d and inr: runs.append((st,y-1));inr=False
if inr: runs.append((st,139))
print('  暗谷:', runs)

print()
print('=== 00_player 灯槽横向剖面 y=60（找亮条与暗框）===')
row=[lum(*R[60][x])/255 for x in range(w)]
# 找 lum>0.80 的段
runs=[];inr=False
for x in range(8,472):
    d = row[x] > 0.80
    if d and not inr: st=x;inr=True
    elif not d and inr: runs.append((st,x-1));inr=False
if inr: runs.append((st,471))
print('  y=60 亮段(>0.80):', runs)

print()
print('=== 00_player 水平缝检测：逐列竖向 lum 方差（x=430..470 右墙区）===')
for x in range(440,452):
    vals=[lum(*R[y][x]) for y in range(60,200)]
    m=sum(vals)/len(vals)
    var=sum((v-m)**2 for v in vals)/len(vals)
    print('  x=%3d mean=%6.1f sd=%5.2f' % (x,m,var**0.5))
