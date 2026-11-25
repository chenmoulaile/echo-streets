import sys, math
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b

def load(n):
    w,h,R = read_png(S % n); return w,h,R

def reg(R,x0,y0,x1,y1):
    n=0;s=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            s+=lum(*R[y][x]); n+=1
    return s/n/255

w,h,R = load('ch01_01_center')
print('=== 01_center 天花：中轴带 vs 两侧（y=10..70）===')
for x0,x1,lab in [(200,280,'center 200-280'),(150,200,'left 150-200'),
                  (280,330,'right 280-330'),(100,150,'far-left 100-150'),
                  (330,380,'far-right 330-380')]:
    print('  %-18s %.3f' % (lab, reg(R,x0,10,x1,70)))

print()
print('=== 01_center 地板：中轴带 vs 两侧（y=200..265）===')
for x0,x1,lab in [(200,280,'center band'),(100,180,'left white'),(300,380,'right white')]:
    print('  %-18s %.3f' % (lab, reg(R,x0,200,x1,265)))

print()
w,h,R = load('ch01_00_player')
print('=== 00_player 天花：中轴带 vs 两侧（y=10..75）===')
for x0,x1,lab in [(200,280,'center 200-280'),(150,200,'left 150-200'),
                  (280,330,'right 280-330'),(80,150,'far-left'),(330,400,'far-right')]:
    print('  %-18s %.3f' % (lab, reg(R,x0,10,x1,75)))

print()
print('=== 00_player 灯槽暗框（x=84..159, y=50..70 逐行）===')
for y in range(48,72):
    vals=[lum(*R[y][x])/255 for x in range(84,160)]
    print('  y=%3d mean=%.3f min=%.3f max=%.3f' % (y,sum(vals)/len(vals),min(vals),max(vals)))

print()
w,h,R = load('ch01_04_left')
print('=== 04_left 纯红带定位（B==0 且 R>0）===')
tot=0; byrow={}
for y in range(8,262):
    c=0
    for x in range(8,472):
        r,g,b=R[y][x]
        if b==0 and r>0:
            c+=1; tot+=1
    if c>50: byrow[y]=c
print('  B==0 像素总数=%d  占比=%.2f%%' % (tot, 100.0*tot/(464*254)))
ys=sorted(byrow)
print('  含>50 个纯红像素的行: y=%s .. %s  共 %d 行' % (ys[0] if ys else '-', ys[-1] if ys else '-', len(ys)))
for y in ys[:12]:
    print('    y=%3d n=%d' % (y,byrow[y]))

print()
print('=== 04_left 蓝裙 RGB 均值与饱和度 ===')
for y0,y1,lab in [(166,180,'skirt upper'),(182,196,'skirt lower'),(60,150,'sky panes')]:
    rs=gs=bs=0;n=0;mx=0
    for y in range(y0,y1):
        for x in range(60,420):
            r,g,b=R[y][x]; rs+=r;gs+=g;bs+=b;n+=1
            s=(max(r,g,b)-min(r,g,b))*100//max(max(r,g,b),1)
            if s>mx: mx=s
    print('  %-12s rgb(%3d,%3d,%3d)  maxSat=%d%%' % (lab,rs//n,gs//n,bs//n,mx))
