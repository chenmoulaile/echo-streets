import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return (0.299*r+0.587*g+0.114*b)/255.0
def load(n):
    w,h,R = read_png(S % n); return w,h,R

F=175.9; CX=240.0; CY=135.0; CAMY=1.6; CAMZ=18.0
w,h,R = load('ch01_00_player')
print('=== 00_player 地板：灯正下方 vs 两灯中点（沿 z 扫描，取 x=200..280 平均）===')
# 灯 z 序列 -19,-12.5,-6,0.5,7,13.5 ; 灯 x=+-3.0 -> 地面投影
for wz in (13.5, 12.0, 10.25, 7.0, 5.0, 3.75, 0.5, -2.0, -6.0):
    d = CAMZ - wz
    if d <= 0: continue
    sy = CY + CAMY*F/d
    y = int(round(sy))
    if y < 8 or y > 261: continue
    vals=[lum(*R[y][x]) for x in range(196,286)]
    print('  z=%6.2f dist=%5.2f  y=%3d  floor mean=%.3f' % (wz,d,y,sum(vals)/len(vals)))

print()
print('=== 00_player 天花 dither 棋盘幅度（平坦区 x=160..200, y=20..40）===')
vals=[[lum(*R[y][x]) for x in range(160,200)] for y in range(20,40)]
flat=[v for row in vals for v in row]
m=sum(flat)/len(flat)
print('  mean=%.3f min=%.3f max=%.3f range=%.1f/255' % (m,min(flat),max(flat),(max(flat)-min(flat))*255))
# 4x4 周期检测
for py in range(2):
    for px in range(4):
        s=[vals[y][x] for y in range(py,20,4) for x in range(px,40,4)]
        print('   phase(%d,%d) mean=%.3f' % (py,px,sum(s)/len(s)))

print()
print('=== 00_player 白砖 dither 棋盘幅度（x=150..190, y=200..230）===')
vals=[[lum(*R[y][x]) for x in range(150,190)] for y in range(200,230)]
flat=[v for row in vals for v in row]
m=sum(flat)/len(flat)
print('  mean=%.3f min=%.3f max=%.3f range=%.1f/255' % (m,min(flat),max(flat),(max(flat)-min(flat))*255))

print()
print('=== 03_right 墙面是否真无纹理（x=200..330, y=70..140 逐列均值方差）===')
w,h,R = load('ch01_03_right')
cols=[]
for x in range(200,331):
    cols.append(sum(lum(*R[y][x]) for y in range(70,141))/71)
m=sum(cols)/len(cols)
sd=(sum((c-m)**2 for c in cols)/len(cols))**0.5
print('  列均值 mean=%.3f sd=%.4f (=%.1f/255)  min=%.3f max=%.3f' % (m,sd,sd*255,min(cols),max(cols)))
rows=[]
for y in range(70,141):
    rows.append(sum(lum(*R[y][x]) for x in range(200,331))/131)
m2=sum(rows)/len(rows)
sd2=(sum((c-m2)**2 for c in rows)/len(rows))**0.5
print('  行均值 mean=%.3f sd=%.4f (=%.1f/255)  min=%.3f max=%.3f' % (m2,sd2,sd2*255,min(rows),max(rows)))
