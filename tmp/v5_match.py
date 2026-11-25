import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return (0.299*r+0.587*g+0.114*b)/255.0
def load(n):
    w,h,R = read_png(S % n); return w,h,R

F=175.9; CX=240.0; CY=135.0; CAMY=1.6
print('=== 00_player 同距离 天花 vs 地板（避开灯槽/梁，取 x=170..190 与 x=290..310 平均）===')
w,h,R = load('ch01_00_player')
for dz in (4.2,5.0,6.0,8.0,10.0,13.0):
    sy_c = CY - (3.6-CAMY)*F/dz
    sy_f = CY + CAMY*F/dz
    yc=int(round(sy_c)); yf=int(round(sy_f))
    if yc<8 or yf>261: continue
    cv=[lum(*R[yc][x]) for x in list(range(168,192))+list(range(288,312))]
    fv=[lum(*R[yf][x]) for x in list(range(168,192))+list(range(288,312))]
    print('  dz=%4.1f  ceil y=%3d mean=%.3f | floor y=%3d mean=%.3f | ceil/floor=%.2f' % (
        dz,yc,sum(cv)/len(cv),yf,sum(fv)/len(fv),(sum(cv)/len(cv))/max(sum(fv)/len(fv),1e-6)))

print()
print('=== 01_center 同距离 天花 vs 地板（机位 (0,2.4,0)，CAMY=2.4）===')
w,h,R = load('ch01_01_center')
CAMY2=2.4
for dz in (4.2,5.0,6.0,8.0,10.0):
    sy_c = CY - (3.6-CAMY2)*F/dz
    sy_f = CY + CAMY2*F/dz
    yc=int(round(sy_c)); yf=int(round(sy_f))
    if yc<8 or yf>261: continue
    cv=[lum(*R[yc][x]) for x in list(range(120,200))+list(range(280,360))]
    fv=[lum(*R[yf][x]) for x in list(range(120,200))+list(range(280,360))]
    print('  dz=%4.1f  ceil y=%3d mean=%.3f | floor y=%3d mean=%.3f | ceil/floor=%.2f' % (
        dz,yc,sum(cv)/len(cv),yf,sum(fv)/len(fv),(sum(cv)/len(cv))/max(sum(fv)/len(fv),1e-6)))

print()
print('=== 00_player 中轴带 y=190 细扫 x=190..292（步长 2）===')
w,h,R = load('ch01_00_player')
prev=None
for x in range(190,293,2):
    t=R[190][x]; print('  x=%3d %s lum=%.3f' % (x,str(t),lum(*t)))
