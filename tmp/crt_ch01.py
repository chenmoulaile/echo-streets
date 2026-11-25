import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
from crop_ch01 import write_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

# A) 曲率黑边精确宽度（中列/中行）
for f in ['ch01_00_player', 'ch01_02_back', 'ch01_04_left', 'ch01_05_top']:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    def firstlit(seq):
        for i, (x, y) in enumerate(seq):
            r, g, b = rows[y][x]
            if lum(r, g, b) > 2:
                return i, (x, y)
        return -1, None
    l = firstlit([(x, 135) for x in range(w)])
    r_ = firstlit([(x, 135) for x in range(w-1, -1, -1)])
    t = firstlit([(240, y) for y in range(h)])
    b_ = firstlit([(240, y) for y in range(h-1, -1, -1)])
    print('%s  black border: left=%d right=%d top=%d bottom=%d' % (
        f, l[0], r_[0], t[0], b_[0]))

# 曲率理论值：uv.x>=0 需 c.x*1.03 >= -1
for cy in [0.0, 0.5, 1.0]:
    c = [0.0, cy*2-1]
    need = -1.0 / (1.0 + 0.06*0.5*(1.0 + c[1]*c[1]))
    print('  theory curvature=0.06 at cy=%.1f -> uv.x_min=%.4f -> %.1f px of 480' % (
        cy, (need*0.5+0.5), ((need*0.5+0.5))*480))

# B) ch01_02_back 水平黑线
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\ch01_02_back.png')
print('== ch01_02_back 整行均值 y=95..125')
out = []
for y in range(95, 126):
    s = sum(lum(*rows[y][x]) for x in range(10, 470)) / 460.0
    out.append('%d:%.0f' % (y, s))
print('   ' + ' '.join(out))
print('== ch01_02_back y=111 逐段 x=0..479 step 20')
print('   ' + ' '.join('%d:%d' % (x, lum(*rows[111][x])) for x in range(0, 480, 20)))
print('== ch01_02_back y=110 逐段')
print('   ' + ' '.join('%d:%d' % (x, lum(*rows[110][x])) for x in range(0, 480, 20)))

# C) top8 max=255 来源
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\ch01_00_player.png')
hits = [(x, y) for y in range(0, 8) for x in range(w) if lum(*rows[y][x]) > 240]
print('== ch01_00_player top8 pixels lum>240: n=%d  sample=%s' % (
    len(hits), hits[:12]))
allhits = [(x, y, rows[y][x]) for y in range(h) for x in range(w) if lum(*rows[y][x]) > 240]
print('   whole image lum>240: n=%d  sample=%s' % (len(allhits), allhits[:10]))
mx = max((lum(*rows[y][x]), x, y) for y in range(h) for x in range(w))
print('   true max lum=%.1f at %s' % (mx[0], mx[1:]))
