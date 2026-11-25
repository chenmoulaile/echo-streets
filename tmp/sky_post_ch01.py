import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
from crop_ch01 import write_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

# --- 1) 天空贴图：整图降采样 + 可见带 v 0.406..0.688 的行剖面 ---
p = r'D:\mygame\assets\materials\SkyTexture_Sunset.png'
w, h, rows = read_png(p)
print('sky %dx%d' % (w, h))
# 每 40 行取一条平均色，找地平线
for y in range(0, h, 40):
    sr = sg = sb = 0
    n = 0
    for x in range(0, w, 20):
        r, g, b = rows[y][x]
        sr += r; sg += g; sb += b; n += 1
    print('  y=%4d (v=%.3f)  #%02X%02X%02X  lum=%.2f' % (
        y, y/h, sr//n, sg//n, sb//n, lum(sr/n, sg/n, sb/n)/255))

# 缩略图 48x12
small = []
for j in range(24):
    line = []
    y = int(j * h / 24)
    for i in range(96):
        x = int(i * w / 96)
        line.append(rows[y][x])
    small.append(line)
write_png(r'D:\mygame\tmp\sky_thumb.png', small)
print('thumb saved')

# --- 2) 后处理数值模拟 ---
POST = dict(brightness=1.10, contrast=1.03, saturation=1.12, lift=0.045,
            vignette=0.14, scanline=0.06, levels=8.0)

def bayer2(ax, ay):
    v = (ax * 0.5 + ay * ay * 0.75)
    return v - int(v)

def bayer4(bx, by):
    bx %= 4; by %= 4
    return bayer2(bx, by) + bayer2(bx // 2, by // 2) * 0.25

def post_img(f, x0=0, y0=0, x1=480, y1=270):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    clip = 0; dark = 0; n = 0
    vals = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            col = [r/255.0, g/255.0, b/255.0]
            l = 0.299*col[0] + 0.587*col[1] + 0.114*col[2]
            col = [l + (c-l)*POST['saturation'] for c in col]
            col = [(c-0.5)*POST['contrast'] + 0.5 + POST['lift'] for c in col]
            col = [c*POST['brightness'] for c in col]
            d = (bayer4(x, y) - 0.5) * 1.0
            col = [int(c*POST['levels'] + d)/POST['levels'] for c in col]
            row = y
            col = [c*(1.0-POST['scanline']*(row % 2)) for c in col]
            vx = x/480.0 - 0.5; vy = y/270.0 - 0.5
            vig = 1.0 - (vx*vx+vy*vy)*POST['vignette']*1.6
            vig = max(0.0, min(1.0, vig))
            col = [max(0.0, min(1.0, c*vig)) for c in col]
            L = lum(*col)*255
            vals.append(L); n += 1
            if min(col) >= 1.0: clip += 1
            if L < 38: dark += 1
    vals.sort()
    print('post %-16s mean=%.0f p1=%.0f p50=%.0f p95=%.0f max=%.0f  clip=%.2f%% dark<38=%.2f%%' % (
        f, sum(vals)/n, vals[n//100], vals[n//2], vals[n*95//100], vals[-1],
        100.0*clip/n, 100.0*dark/n))

for f in ['ch01_00_player', 'ch01_01_center', 'ch01_02_back',
          'ch01_03_right', 'ch01_04_left']:
    post_img(f)
print('-- 右墙脚区域 post')
post_img('ch01_03_right', 100, 40, 380, 140)
print('-- 出生点地板 post')
post_img('ch01_00_player', 40, 200, 180, 260)
