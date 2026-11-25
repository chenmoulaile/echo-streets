import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

w,h,R = read_png(S % 'ch01_00_player')
w1,h1,R1 = read_png(S % 'ch01_01_center')
w3,h3,R3 = read_png(S % 'ch01_03_right')
w4,h4,R4 = read_png(S % 'ch01_04_left')

print('### A. 中轴导视带边缘（00_player y=250，找左右边界）')
row = [(x, lum(*R[250][x])) for x in range(8, 472)]
# 找 <130 的连续段
dark = [x for x,v in row if v < 130]
runs=[]
if dark:
    s=dark[0]; p=dark[0]
    for x in dark[1:]:
        if x-p>1: runs.append((s,p)); s=x
        p=x
    runs.append((s,p))
print('  y=250 lum<130 段:', runs)
for y in [200, 220, 240, 260]:
    dark = [x for x in range(8,472) if lum(*R[y][x]) < 130]
    runs=[]
    if dark:
        s=dark[0]; p=dark[0]
        for x in dark[1:]:
            if x-p>1: runs.append((s,p)); s=x
            p=x
        runs.append((s,p))
    print('  y=%3d lum<130 段: %s' % (y, runs))

print()
print('### B. 中轴带远端边缘锯齿（y=150..175 逐行边界 x）')
for y in range(150, 176, 2):
    dark = [x for x in range(150,340) if lum(*R[y][x]) < 120]
    if dark:
        print('  y=%3d 暗段 x=%d..%d (宽 %d)' % (y, min(dark), max(dark), max(dark)-min(dark)+1))
    else:
        print('  y=%3d 无暗段' % y)

print()
print('### C. 灯槽在 00_player 的屏幕位置（找 x=±3.0 对应像素）')
# 机位 (0,1.6,18)，fov 75 垂直，480x270
import math
def project(px,py,pz):
    dz = 18.0 - pz  # 朝 -Z
    if dz <= 0.1: return None
    f = 135.0 / math.tan(math.radians(37.5))
    sx = 240.0 + px * f / dz
    sy = 135.0 - (py - 1.6) * f / dz
    return (sx, sy)
for z in [13.5, 7.0, 0.5, -6.0, -12.5, -19.0]:
    a = project(-3.0, 3.4, z); b = project(3.0, 3.4, z)
    print('  z=%6.1f  灯 x=-3 -> (%.0f,%.0f)   x=+3 -> (%.0f,%.0f)' % (z, a[0],a[1], b[0],b[1]))

print()
print('### D. 这些位置的实测亮度（00_player）')
for z in [13.5, 7.0, 0.5, -6.0, -12.5, -19.0]:
    a = project(-3.0, 3.4, z); b = project(3.0, 3.4, z)
    for lab,(sx,sy) in [('L',a),('R',b)]:
        ix, iy = int(round(sx)), int(round(sy))
        if 8 <= ix < 472 and 8 <= iy < 262:
            print('  z=%6.1f %s (x=%3d,y=%3d) lum=%.3f rgb=%s' % (z, lab, ix, iy, lum(*R[iy][ix])/255, R[iy][ix]))
        else:
            print('  z=%6.1f %s 出屏 (%.0f,%.0f)' % (z, lab, sx, sy))

print()
print('### E. 售货机 UV 核算')
print('  box UV = world*0.5 -> 1 tile = 2 米')
print('  售货机正面 0.72 米宽 x 1.95 米高 -> UV 跨度 (0.36, 0.975)')
print('  贴图 200x200 -> 显示 72x195 px 内容 = 贴图左侧 36% 宽')
print('  即只显示贴图 72/200 的横向内容，机器图案被裁掉右侧 64%')

print()
print('### F. 03_right 售货机像素取样（正面）')
# 03_right 机位 (7,1.6,2) yaw -70
for (x0,y0,x1,y1,lab) in [(20,110,70,200,'vend@z=-2.5'),(265,105,325,205,'vend@z=6.5')]:
    n=0;s=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            s+=lum(*R3[y][x]); n+=1
    print('  %-14s mean=%.3f' % (lab, s/n/255))

print()
print('### G. 04_left 蓝裙精确 RGB 分布（y=170..200, x=60..420）')
hist={}
for y in range(170,200):
    for x in range(60,421):
        hist[R4[y][x]] = hist.get(R4[y][x],0)+1
tot=sum(hist.values())
for p,c in sorted(hist.items(), key=lambda kv:-kv[1])[:8]:
    print('    %s x%d (%.1f%%)' % (p,c,100.0*c/tot))

print()
print('### H. 天花中轴暗带（00_player x=230..250 y=8..70）vs 两侧 (x=150..200 / 280..330)')
for (x0,x1,lab) in [(150,200,'左'),(230,250,'中轴'),(280,330,'右')]:
    n=0;s=0
    for y in range(8,71):
        for x in range(x0,x1):
            s+=lum(*R[y][x]); n+=1
    print('  天花 %s (x=%d..%d) mean=%.3f' % (lab,x0,x1,s/n/255))
