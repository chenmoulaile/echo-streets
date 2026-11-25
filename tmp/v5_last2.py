import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
def load(n):
    w,h,R = read_png(S % n); return w,h,R

w,h,R = load('ch01_00_player')
print('=== 00_player 远端中轴带边界（阈值 lum<0.50 找连续段，中心 x=240）===')
for y in range(140,200,2):
    row=[lum(*R[y][x])/255 for x in range(w)]
    # 从中心向左右扩展，找第一次 >0.55
    l=240
    while l>8 and row[l]<0.55: l-=1
    r=240
    while r<471 and row[r]<0.55: r+=1
    print('  y=%3d band x=%3d..%3d width=%3d  center_lum=%.3f  neighbor=%.3f' % (
        y,l,r,r-l,row[240],row[max(l-6,8)]))

print()
print('=== 00_player 中轴带纵向亮度（x=240）确认无 Z-fighting 条纹 ===')
vals=[]
for y in range(160,265):
    vals.append(lum(*R[y][240])/255)
# 找相邻行跳变
jumps=[(y+160, abs(vals[y+1]-vals[y])) for y in range(len(vals)-1)]
big=[j for j in jumps if j[1]>0.06]
print('  相邻行 |Δ|>0.06 的位置:', big[:20], '共', len(big))

print()
print('=== 00_player 灯槽：找 y 方向的暗框边界（x=123 灯槽中心）===')
for y in range(46,72):
    print('  y=%2d x=123 lum=%.3f   x=100 lum=%.3f  x=150 lum=%.3f' % (
        y, lum(*R[y][123])/255, lum(*R[y][100])/255, lum(*R[y][150])/255))

print()
w,h,R = load('ch01_03_right')
print('=== 03_right 售货机贴图裁切验证：找箱体左右边界与内部图案分布 ===')
# 售货机是蓝色系；找蓝色像素（B > R+20）
for y in (70,90,110,130):
    seg=[];inr=False
    for x in range(8,472):
        r,g,b=R[y][x]
        d = (b > r+18)
        if d and not inr: st=x;inr=True
        elif not d and inr:
            if x-st>6: seg.append((st,x-1))
            inr=False
    print('  y=%3d 蓝色箱体段:' % y, seg)
print()
print('=== 03_right 最右售货机（x≈330..350）逐列亮度：图案是否只占左侧一半 ===')
for x in range(328,352,2):
    vals=[lum(*R[y][x]) for y in range(95,160)]
    print('  x=%3d mean=%5.1f sd=%5.2f' % (x,sum(vals)/len(vals),(sum((v-sum(vals)/len(vals))**2 for v in vals)/len(vals))**0.5))
