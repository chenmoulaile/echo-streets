import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
NAMES = ['ch01_00_player','ch01_01_center','ch01_02_back',
         'ch01_03_right','ch01_04_left','ch01_05_top']

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b

def stats(R, x0,y0,x1,y1):
    n=0; s=0; clip=0; dark=0; pure=0; mx=0; vals=[]
    for y in range(y0,y1):
        row=R[y]
        for x in range(x0,x1):
            r,g,b=row[x]
            L=lum(r,g,b)
            s+=L; n+=1
            if L>=250: clip+=1
            if L<38: dark+=1
            if r==0 and g==0 and b==0: pure+=1
            if L>mx: mx=L
            vals.append(L)
    vals.sort()
    return dict(n=n, mean=s/n, p50=vals[n//2], p95=vals[int(n*0.95)],
                max=mx, clip=100.0*clip/n, dark=100.0*dark/n, pure=100.0*pure/n)

print('=== 全图 vs 内部(排除8px边) ===')
for nm in NAMES:
    w,h,R = read_png(S % nm)
    a = stats(R,0,0,w,h)
    b = stats(R,8,8,w-8,h-8)
    print('%-16s FULL mean=%5.1f p50=%5.1f p95=%5.1f max=%5.1f clip=%.2f%% dark=%.2f%% pure=%.2f%%' %
          (nm, a['mean'],a['p50'],a['p95'],a['max'],a['clip'],a['dark'],a['pure']))
    print('%-16s INNER mean=%5.1f p50=%5.1f p95=%5.1f max=%5.1f clip=%.2f%% dark=%.2f%% pure=%.2f%%' %
          ('', b['mean'],b['p50'],b['p95'],b['max'],b['clip'],b['dark'],b['pure']))

print()
print('=== CRT 黑边宽度 ===')
for nm in NAMES:
    w,h,R = read_png(S % nm)
    def isblk(p): return p[0]==0 and p[1]==0 and p[2]==0
    left=0
    while left<w and isblk(R[h//2][left]): left+=1
    right=0
    while right<w and isblk(R[h//2][w-1-right]): right+=1
    top=0
    while top<h and isblk(R[top][w//2]): top+=1
    bot=0
    while bot<h and isblk(R[h-1-bot][w//2]): bot+=1
    print('%-16s left=%d right=%d top=%d bottom=%d' % (nm,left,right,top,bot))
