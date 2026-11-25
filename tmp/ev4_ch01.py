import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

print('### 1. CRT 黑边精确宽度（六图四边，找第一列/行非纯黑）')
for f in ['ch01_00_player','ch01_01_center','ch01_02_back','ch01_03_right','ch01_04_left','ch01_05_top']:
    w,h,rows = read_png(S % f)
    def first_nonblack_x(y, rev=False):
        rng = range(w-1, -1, -1) if rev else range(w)
        for x in rng:
            if rows[y][x] != (0,0,0):
                return x
        return -1
    def first_nonblack_y(x, rev=False):
        rng = range(h-1, -1, -1) if rev else range(h)
        for y in rng:
            if rows[y][x] != (0,0,0):
                return y
        return -1
    L = first_nonblack_x(h//2); R = w-1-first_nonblack_x(h//2, True)
    T = first_nonblack_y(w//2); B = h-1-first_nonblack_y(w//2, True)
    print('  %-16s left=%d right=%d top=%d bottom=%d' % (f, L, R, T, B))

print()
print('### 2. 前台区域 Z-fighting 高频检测（00_player x=215..265 y=126..142）')
w,h,rows = read_png(S % 'ch01_00_player')
for y in range(126, 143):
    vals = [lum(*rows[y][x]) for x in range(215, 266)]
    # 相邻差 > 25 的次数 = 高频闪烁特征
    hi = sum(1 for i in range(len(vals)-1) if abs(vals[i+1]-vals[i]) > 25)
    print('  y=%3d mean=%5.1f  相邻差>25 次数=%2d/%d  %s' % (
        y, sum(vals)/len(vals), hi, len(vals)-1,
        ' '.join('%3.0f' % v for v in vals[:26])))

print()
print('### 3. 扫描线幅度（03_right 墙面平坦区 x=200..300，逐行均值）')
w3,h3,r3 = read_png(S % 'ch01_03_right')
prev = None
diffs = []
for y in range(50, 130):
    m = sum(lum(*r3[y][x]) for x in range(200, 301))/101.0
    if prev is not None:
        diffs.append((y, m, m-prev))
    prev = m
print('  前 16 行：')
for y, m, d in diffs[:16]:
    print('    y=%3d mean=%6.2f  delta=%+6.2f' % (y, m, d))
odd = [m for y,m,d in diffs if y % 2 == 1]
even = [m for y,m,d in diffs if y % 2 == 0]
print('  奇数行均值=%.2f  偶数行均值=%.2f  差=%.2f (%.1f%%)' % (
    sum(odd)/len(odd), sum(even)/len(even),
    sum(even)/len(even)-sum(odd)/len(odd),
    100.0*(sum(even)/len(even)-sum(odd)/len(odd))/((sum(even)+sum(odd))/2)))

print()
print('### 4. 色差幅度（00_player 白砖区 y=240 相邻像素通道分离）')
w0,h0,r0 = read_png(S % 'ch01_00_player')
row = [(x, r0[240][x]) for x in range(100, 140)]
print('  x: (R,G,B)')
for x, p in row:
    print('    x=%3d %s' % (x, p))

print()
print('### 5. 柱础像素直方图（00_player x=96..122 y=162..168）')
hist = {}
for y in range(162, 169):
    for x in range(96, 123):
        p = r0[y][x]
        hist[p] = hist.get(p, 0) + 1
for p, c in sorted(hist.items(), key=lambda kv: -kv[1])[:10]:
    print('    %s x%d' % (p, c))

print()
print('### 6. 踢脚线像素（03_right x=150..330 y=205..222 直方图）')
hist = {}
for y in range(205, 223):
    for x in range(150, 331):
        p = r3[y][x]
        hist[p] = hist.get(p, 0) + 1
tot = sum(hist.values())
for p, c in sorted(hist.items(), key=lambda kv: -kv[1])[:10]:
    print('    %s x%d (%.1f%%)' % (p, c, 100.0*c/tot))
