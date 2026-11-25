import sys, os, time
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'
FILES = ['ch01_00_player','ch01_01_center','ch01_02_back',
         'ch01_03_right','ch01_04_left','ch01_05_top']

print('### 文件时间戳与大小')
for f in FILES:
    p = S % f
    print('  %-16s %s  %d bytes' % (f, time.strftime('%H:%M:%S', time.localtime(os.path.getmtime(p))), os.path.getsize(p)))

print()
print('### 全图统计（含 CRT 黑边）与内部统计（排除 8px 边）')
for f in FILES:
    w,h,rows = read_png(S % f)
    def calc(x0,y0,x1,y1):
        n=0; s=0; clip=0; dark=0; pure=0; vals=[]
        for y in range(y0,y1):
            for x in range(x0,x1):
                p = rows[y][x]; L = lum(*p)
                vals.append(L); s+=L; n+=1
                if L>=250: clip+=1
                if L<38: dark+=1
                if p==(0,0,0): pure+=1
        vals.sort()
        return (s/n, vals[n//2], vals[int(n*0.95)], 100.0*clip/n, 100.0*dark/n, 100.0*pure/n)
    a = calc(0,0,w,h)
    b = calc(8,8,w-8,h-8)
    print('  %-16s 全图 mean=%5.1f p50=%5.1f p95=%5.1f clip=%4.1f%% dark=%4.1f%% pure=%4.1f%%' % (f,)+())  if False else None
    print('  %-16s 全图 mean=%5.1f p50=%5.1f p95=%5.1f clip>=250=%5.1f%% dark<38=%5.1f%% pure0=%5.1f%%' % ((f,)+a))
    print('  %-16s 内部 mean=%5.1f p50=%5.1f p95=%5.1f clip>=250=%5.1f%% dark<38=%5.1f%% pure0=%5.1f%%' % (('',)+b))
