import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
from crop_ch01 import write_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

# 主墙贴图 WhiteWall 放大 3x 看细节
for name in ['WhiteWall', 'CeramicFloor_White', 'MetalPlateWall']:
    w, h, rows = read_png(r'D:\mygame\assets\materials\%s.png' % name)
    big = []
    for y in range(h):
        line = []
        for x in range(w):
            line.extend([rows[y][x]] * 3)
        big.extend([line] * 3)
    write_png(r'D:\mygame\tmp\mat_%s.png' % name, big)
    # 统计梯度
    gsum = 0.0; gn = 0
    mx = 0
    for y in range(1, h):
        for x in range(1, w):
            a = lum(*rows[y][x]); b2 = lum(*rows[y-1][x]); c = lum(*rows[y][x-1])
            g = abs(a-b2) + abs(a-c)
            gsum += g; gn += 1
            mx = max(mx, g)
    print('%-22s %dx%d  meanGrad=%.2f maxGrad=%.0f' % (name, w, h, gsum/gn, mx))

# 灯 z 序列
print('lamp z from -19 step 6.5:', [-19 + 6.5*i for i in range(10) if -19 + 6.5*i <= 19])
# 出生点 z=18 到最近灯的 z 距离
zs = [-19 + 6.5*i for i in range(6)]
print('nearest lamp z to 18:', max(zs), 'delta=', 18 - max(zs))

# post 后暗像素分布（ch01_04_left）
POST = dict(brightness=1.10, contrast=1.03, saturation=1.12, lift=0.045,
            vignette=0.14, scanline=0.06, levels=8.0)
def bayer2(ax, ay):
    v = ax * 0.5 + ay * ay * 0.75
    return v - int(v)
def bayer4(bx, by):
    bx %= 4; by %= 4
    return bayer2(bx, by) + bayer2(bx // 2, by // 2) * 0.25

def postmap(f):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    out = []
    for y in range(h):
        line = []
        for x in range(w):
            r, g, b = rows[y][x]
            col = [r/255.0, g/255.0, b/255.0]
            l = lum(*col)
            col = [l + (c-l)*POST['saturation'] for c in col]
            col = [(c-0.5)*POST['contrast'] + 0.5 + POST['lift'] for c in col]
            col = [c*POST['brightness'] for c in col]
            d = (bayer4(x, y) - 0.5) * 1.0
            col = [int(c*POST['levels'] + d)/POST['levels'] for c in col]
            col = [c*(1.0-POST['scanline']*(y % 2)) for c in col]
            vx = x/480.0 - 0.5; vy = y/270.0 - 0.5
            vig = max(0.0, min(1.0, 1.0 - (vx*vx+vy*vy)*POST['vignette']*1.6))
            col = [max(0.0, min(1.0, c*vig)) for c in col]
            line.append((int(col[0]*255), int(col[1]*255), int(col[2]*255)))
        out.append(line)
    write_png(r'D:\mygame\tmp\post_%s.png' % f, out)
    return out

for f in ['ch01_04_left', 'ch01_03_right', 'ch01_00_player']:
    out = postmap(f)
    print('== %s post dark<38 clusters' % f)
    d = {}
    for y in range(270):
        for x in range(480):
            if lum(*out[y][x]) < 38:
                d.setdefault((y//10)*10, []).append(x)
    for k in sorted(d):
        if len(d[k]) < 40:
            continue
        print('   y=%3d-%3d n=%4d x=%3d..%3d' % (k, k+9, len(d[k]), min(d[k]), max(d[k])))
