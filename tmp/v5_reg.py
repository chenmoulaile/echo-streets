import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

S = r'D:\mygame\tmp\shots\chapter\%s.png'
def lum(r,g,b): return 0.299*r+0.587*g+0.114*b

def reg(R,x0,y0,x1,y1):
    n=0;s=0;mn=999;mx=-1
    for y in range(y0,y1):
        for x in range(x0,x1):
            L=lum(*R[y][x]); s+=L; n+=1
            if L<mn: mn=L
            if L>mx: mx=L
    return (s/n/255, mn/255, mx/255)

w,h,R = read_png(S % 'ch01_00_player')

print('=== ch01_00_player 区域（lum 0..1, min, max）===')
regions = [
 (60,235,140,262,'floor white near-L'),
 (340,235,420,262,'floor white near-R'),
 (60,200,140,235,'floor white mid-L'),
 (340,200,420,235,'floor white mid-R'),
 (200,235,280,262,'center band near'),
 (200,200,280,235,'center band mid'),
 (200,150,280,185,'center band far'),
 (60,8,420,25,'ceiling near top'),
 (150,20,330,60,'ceiling center'),
 (60,60,140,100,'ceiling left mid'),
 (340,60,420,100,'ceiling right mid'),
 (95,110,120,158,'col body L'),
 (96,162,122,169,'col base L'),
 (250,110,275,158,'col body R'),
 (250,162,276,169,'col base R'),
 (14,150,40,175,'sky pane near'),
 (14,100,40,130,'sky pane upper'),
 (14,178,60,200,'blue skirt'),
 (300,120,330,160,'right wall upper'),
 (300,175,330,215,'right wall lower'),
 (240,140,250,160,'far reception'),
]
for x0,y0,x1,y1,lab in regions:
    m,mn,mx = reg(R,x0,y0,x1,y1)
    print('  %-22s mean=%.3f min=%.3f max=%.3f' % (lab,m,mn,mx))

print()
print('=== 逐行剖面 x=240 (中轴) ===')
for y in range(8,262,4):
    r,g,b = R[y][240]
    print('  y=%3d rgb(%3d,%3d,%3d) lum=%.3f' % (y,r,g,b,lum(r,g,b)/255))

print()
print('=== 天花剖面 x=150 (左中) ===')
for y in range(8,120,4):
    r,g,b = R[y][150]
    print('  y=%3d rgb(%3d,%3d,%3d) lum=%.3f' % (y,r,g,b,lum(r,g,b)/255))
