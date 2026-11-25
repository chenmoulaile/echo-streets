import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r,g,b): return 0.299*r+0.587*g+0.114*b
S = r'D:\mygame\tmp\shots\chapter\%s.png'

w,h,rows = read_png(S % 'ch01_00_player')

print('### A. 地板横向剖面 y=198（找灯池中心 x 坐标）')
for y in [196, 198, 200, 220, 240]:
    vals = [(x, lum(*rows[y][x])) for x in range(8, 472)]
    # 平滑后找局部极大
    sm = []
    for i in range(3, len(vals)-3):
        sm.append((vals[i][0], sum(v[1] for v in vals[i-3:i+4])/7.0))
    peaks = []
    for i in range(4, len(sm)-4):
        if sm[i][1] > sm[i-1][1] and sm[i][1] > sm[i+1][1] and sm[i][1] > 150:
            if not peaks or sm[i][0] - peaks[-1][0] > 20:
                peaks.append((sm[i][0], round(sm[i][1],1)))
    print('  y=%d peaks=%s' % (y, peaks[:12]))

print()
print('### B. 天花平坦区 8 级量化验证（01_center x=150..200 y=60..80 直方图）')
w1,h1,r1 = read_png(S % 'ch01_01_center')
hist = {}
for y in range(60, 80):
    for x in range(150, 200):
        v = int(round(lum(*r1[y][x])))
        hist[v] = hist.get(v, 0) + 1
top = sorted(hist.items(), key=lambda kv: -kv[1])[:14]
print('  出现最多的 14 个亮度值:', top)
print('  相邻主峰间隔:', [top[i][0]-top[i+1][0] for i in range(len(top)-1)][:10])

print()
print('### C. 前台纵向剖面 x=225..255（00_player）')
for y in range(108, 150):
    vals = [lum(*rows[y][x]) for x in range(225, 256)]
    print('  y=%3d mean=%5.1f min=%5.1f max=%5.1f  rgb=%s' % (
        y, sum(vals)/len(vals), min(vals), max(vals),
        str(tuple(int(sum(rows[y][x][c] for x in range(225,256))/31) for c in range(3)))))

print()
print('### D. 天花暗梁全宽横剖面 y=81（00_player）')
vals = [(x, lum(*rows[81][x])) for x in range(8, 472)]
dark = [x for x,v in vals if v < 110]
print('  y=81 lum<110 的 x 段数=%d, 前 30 个 x=%s' % (len(dark), dark[:30]))
print('  y=78 mean=%.1f  y=79 mean=%.1f  y=80 mean=%.1f  y=81 mean=%.1f  y=82 mean=%.1f  y=83 mean=%.1f  y=84 mean=%.1f' % tuple(
    sum(lum(*rows[y][x]) for x in range(8,472))/464 for y in range(78,85)))

print()
print('### E. 03_right 墙脚死黑精确取值')
w3,h3,r3 = read_png(S % 'ch01_03_right')
for y in [205, 210, 215, 218, 220, 222, 225]:
    seg = [lum(*r3[y][x]) for x in range(8, 472)]
    below = sum(1 for v in seg if v < 38)
    print('  y=%3d mean=%5.1f min=%5.1f  lum<38 占 %.1f%%  rgb(x=300)=%s' % (
        y, sum(seg)/len(seg), min(seg), 100.0*below/len(seg), r3[y][300]))

print()
print('### F. 05_top 画面上部到底是不是背景色')
w5,h5,r5 = read_png(S % 'ch01_05_top')
for y in [8, 12, 20, 30, 40, 50, 60]:
    seg = [r5[y][x] for x in range(8, 472)]
    uniq = {}
    for px in seg:
        uniq[px] = uniq.get(px, 0) + 1
    top3 = sorted(uniq.items(), key=lambda kv: -kv[1])[:3]
    print('  y=%3d mean_lum=%5.1f  最常见 3 色: %s' % (
        y, sum(lum(*p) for p in seg)/len(seg), top3))

print()
print('### G. 天空板亮度：原贴图 vs 渲染（04_left pane2 x=105..160 y=70..140）')
w4,h4,r4 = read_png(S % 'ch01_04_left')
n=0; sr=sg=sb=0
for y in range(70,140):
    for x in range(105,160):
        r,g,b = r4[y][x]; sr+=r; sg+=g; sb+=b; n+=1
print('  渲染 rgb=(%.0f,%.0f,%.0f)' % (sr/n, sg/n, sb/n))
n=0; sr=sg=sb=0
ww,hh,rr = read_png(r'D:\mygame\assets\materials\sky_window.png')
for y in range(hh):
    for x in range(ww):
        r,g,b = rr[y][x]; sr+=r; sg+=g; sb+=b; n+=1
print('  贴图 rgb=(%.0f,%.0f,%.0f)' % (sr/n, sg/n, sb/n))
