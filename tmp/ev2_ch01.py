import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
import math

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

print('### 1. 05_top 机位几何校验')
# 机位 = start + (0, 6.5, 6), start=(0,0,18) -> (0, 6.5, 24)
print('  机位 (0, 6.5, 24)；H=3.6，HALF_L=23 -> 机位在天花上方 2.9 米、房间外 1.0 米')
print('  pitch=-38 向下看，天花 panel 法线朝 -Y，从上方看是背面 -> 被 cull')

w5,h5,r5 = read_png(S % 'ch01_05_top')
print()
print('### 2. 05_top 纯黑像素分布（判定是背景还是几何）')
for y in range(8, 270, 12):
    seg = [r5[y][x] for x in range(8, 472)]
    black = sum(1 for p in seg if p == (0,0,0))
    print('  y=%3d 纯黑(0,0,0) %3d/%d = %5.1f%%   mean_lum=%5.1f' % (
        y, black, len(seg), 100.0*black/len(seg), sum(lum(*p) for p in seg)/len(seg)))

print()
print('### 3. 后处理量化台阶实测：00_player 柱础 y=164 与 y=166 交替')
w,h,rows = read_png(S % 'ch01_00_player')
for y in [163, 164, 165, 166, 167]:
    vals = [lum(*rows[y][x]) for x in range(96, 122)]
    print('  y=%3d  %s' % (y, ' '.join('%3.0f' % v for v in vals)))
print('  -> 量化台阶间隔实测 ~31 = 255/8，palette_levels=8 生效')

print()
print('### 4. 各图纯黑(0,0,0)像素占比（全图 / 排除 8px 黑边）')
for f in ['ch01_00_player','ch01_01_center','ch01_02_back','ch01_03_right','ch01_04_left','ch01_05_top']:
    ww,hh,rr = read_png(S % f)
    tot=0; pure=0; inner_pure=0; inner_tot=0
    for y in range(hh):
        for x in range(ww):
            p = rr[y][x]
            tot += 1
            if p == (0,0,0): pure += 1
            if 8 <= x < ww-8 and 8 <= y < hh-8:
                inner_tot += 1
                if p == (0,0,0): inner_pure += 1
    print('  %-16s 全图纯黑 %5.2f%%   内部(排黑边)纯黑 %5.2f%%' % (
        f, 100.0*pure/tot, 100.0*inner_pure/inner_tot))

print()
print('### 5. 天花板格栅梁 vs 吊顶本体的亮度比')
for f, yband in [('ch01_00_player', (78,79,80,81,82,83,84,85)), ('ch01_01_center', None)]:
    ww,hh,rr = read_png(S % f)
    if yband:
        for y in yband:
            seg = [lum(*rr[y][x]) for x in range(150, 331)]
            print('  %s y=%3d mean=%5.1f (%.3f)' % (f, y, sum(seg)/len(seg), sum(seg)/len(seg)/255.0))

print()
print('### 6. 前台区域亮度梯度（00_player x=225..255 逐 4 行）')
for y in range(126, 152, 2):
    vals = [lum(*rows[y][x]) for x in range(205, 276)]
    print('  y=%3d mean=%5.1f (%.3f)' % (y, sum(vals)/len(vals), sum(vals)/len(vals)/255.0))

print()
print('### 7. 天空板 tint 链路推演')
print('  贴图均值 rgb=(167,96,57) = (0.655,0.376,0.224)')
print('  x tint(1.0,0.96,0.90) = (0.655,0.361,0.201)')
print('  x post saturation 1.10 + contrast 1.06 -> 实测渲染 (149,66,17) = (0.584,0.259,0.067)')
print('  B 通道 0.224 -> 0.067 = 只剩 30%')
