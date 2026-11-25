import sys, math
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b

F = 175.9   # 135 / tan(37.5deg), fov 75, 480x270
CX, CY = 240.0, 135.0
CAM_Y = 1.6
CAM_Z = 18.0

def sy(world_y, dist):   # dist = 18 - z
    return CY + (CAM_Y - world_y) * F / dist
def sx(world_x, dist):
    return CX + world_x * F / dist

def reg(R,x0,y0,x1,y1):
    n=0;s=0;mn=999;mx=-1
    for y in range(y0,y1):
        for x in range(x0,x1):
            L=lum(*R[y][x]); s+=L; n+=1
            if L<mn: mn=L
            if L>mx: mx=L
    return (s/n/255, mn/255, mx/255)

w,h,R = read_png(S % 'ch01_00_player')

print('=== 几何投影锚点（机位 (0,1.6,18) 朝 -Z, fov75）===')
for d in [2.0, 4.0, 6.0, 9.0, 18.0, 27.0, 36.0, 41.0]:
    z = CAM_Z - d
    print('  dist=%5.1f z=%6.1f  floor_y=%6.1f  ceil_y=%6.1f  band_x=%s  colL_x=%s colR_x=%s' % (
        d, z, sy(0,d), sy(3.6,d),
        '%.0f..%.0f' % (sx(-1.3,d), sx(1.3,d)),
        '%.0f..%.0f' % (sx(-6.95,d), sx(-5.85,d)),
        '%.0f..%.0f' % (sx(5.85,d), sx(6.95,d))))

print()
print('=== 柱础（z=9 排, dist=9）===')
yb0, yb1 = int(sy(0.28,9)), int(sy(0.0,9))+1
print('  柱础屏幕 y=%d..%d' % (yb0,yb1))
for lab, x0, x1 in [('L', int(sx(-6.95,9)), int(sx(-5.85,9))+1),
                    ('R', int(sx(5.85,9)), int(sx(6.95,9))+1)]:
    m,mn,mx = reg(R,x0,yb0,x1,yb1)
    print('   base %s x=%d..%d  mean=%.3f min=%.3f max=%.3f' % (lab,x0,x1,m,mn,mx))
# 柱身
ys0, ys1 = int(sy(3.4,9)), int(sy(0.35,9))
for lab, x0, x1 in [('L', int(sx(-6.95,9)), int(sx(-5.85,9))+1),
                    ('R', int(sx(5.85,9)), int(sx(6.95,9))+1)]:
    m,mn,mx = reg(R,x0,ys0,x1,ys1)
    print('   body %s y=%d..%d  mean=%.3f min=%.3f max=%.3f' % (lab,ys0,ys1,m,mn,mx))

print()
print('=== 右墙剖面（x=11, 逐 dist 取样 y 分带）===')
for d in [9.0, 18.0, 27.0]:
    z = CAM_Z-d
    wx = int(sx(11.0,d))
    if wx < 470:
        for lab, wy0, wy1 in [('upper(2.6-3.6)',2.6,3.6),('mid(1.4-2.6)',1.4,2.6),('lower(0.15-1.4)',0.15,1.4)]:
            m,mn,mx = reg(R, wx-3, int(sy(wy1,d)), wx+4, int(sy(wy0,d)))
            print('  dist=%5.1f sx=%3d %-16s mean=%.3f min=%.3f max=%.3f' % (d,wx,lab,m,mn,mx))

print()
print('=== 左墙（x=-11）蓝裙/玻璃/天空 ===')
for d in [9.0, 18.0, 27.0]:
    wx = int(sx(-11.0,d))
    if wx > 8:
        for lab, wy0, wy1 in [('skirt(0.05-0.88)',0.05,0.88),('glass(1.0-2.4)',1.0,2.4),('glassup(2.5-3.4)',2.5,3.4)]:
            m,mn,mx = reg(R, wx-2, int(sy(wy1,d)), wx+3, int(sy(wy0,d)))
            print('  dist=%5.1f sx=%3d %-18s mean=%.3f min=%.3f max=%.3f' % (d,wx,lab,m,mn,mx))

print()
print('=== 中轴带边界逐行（找 lum 跳变最大的 x）===')
for y in range(170, 268, 6):
    row = [lum(*R[y][x])/255 for x in range(w)]
    # 左边界：在 x=60..240 找最大正跳变
    best=None
    for x in range(60, 240):
        dd = row[x-1]-row[x]
        if best is None or dd>best[0]: best=(dd,x)
    best2=None
    for x in range(240, 460):
        dd = row[x]-row[x-1]
        if best2 is None or dd>best2[0]: best2=(dd,x)
    print('  y=%3d  Ledge x=%3d (jump=%.3f)  Redge x=%3d (jump=%.3f)  width=%3d' % (
        y, best[1], best[0], best2[1], best2[0], best2[1]-best[1]))
