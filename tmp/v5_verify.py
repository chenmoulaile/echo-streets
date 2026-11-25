import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
def load(n):
    w,h,R = read_png(S % n); return w,h,R

# ---- 02_back 顶部暗带性质 ----
w,h,R = load('ch01_02_back')
print('=== 02_back y=4..20 逐行 RGB 抽样（x=100,200,300,400）===')
for y in range(4,22,2):
    print('  y=%2d  ' % y + '  '.join('%s' % (str(R[y][x]),) for x in (100,200,300,400)))

print()
print('=== 02_back 该带内是否存在横向亮线（格栅梁/灯槽）===')
for y in range(4,24):
    vals=[lum(*R[y][x])/255 for x in range(20,460)]
    print('  y=%2d mean=%.3f max=%.3f  n>0.5=%d' % (y,sum(vals)/len(vals),max(vals),sum(1 for v in vals if v>0.5)))

# ---- 03_right 墙脚死黑精确定位 ----
w,h,R = load('ch01_03_right')
print()
print('=== 03_right 逐行 dark<38 与 pure0 占比（y=180..262）===')
for y in range(180,262,2):
    dk=sum(1 for x in range(8,472) if lum(*R[y][x])<38)
    p0=sum(1 for x in range(8,472) if R[y][x]==(0,0,0))
    print('  y=%3d dark=%5.1f%% pure0=%5.1f%% mean=%.1f' % (y,100.0*dk/464,100.0*p0/464,
          sum(lum(*R[y][x]) for x in range(8,472))/464))

# ---- 00_player 柱础 ----
w,h,R = load('ch01_00_player')
print()
print('=== 00_player 柱础像素直方图 (x=104..126, y=160..168) ===')
from collections import Counter
c=Counter()
for y in range(160,169):
    for x in range(104,127):
        c[R[y][x]]+=1
for k,v in c.most_common(10):
    print('   %s x%d' % (str(k),v))

# ---- 04_left 天空格边界硬跳 ----
w,h,R = load('ch01_04_left')
print()
print('=== 04_left y=100 横向：竖挺位置（lum<0.15 段）===')
row=[lum(*R[100][x])/255 for x in range(w)]
runs=[];inr=False
for x in range(8,472):
    d = row[x]<0.15
    if d and not inr: st=x;inr=True
    elif not d and inr: runs.append((st,x-1));inr=False
print('  竖挺暗段:', runs)

print()
print('=== 04_left 每格内部是否有构图（格内 lum 标准差）===')
for i in range(8):
    x0=8+i*58; x1=min(x0+50,471)
    vals=[lum(*R[y][x]) for y in range(60,150) for x in range(x0,x1)]
    m=sum(vals)/len(vals)
    sd=(sum((v-m)**2 for v in vals)/len(vals))**0.5
    print('  pane%d mean=%6.1f sd=%5.2f' % (i,m,sd))
