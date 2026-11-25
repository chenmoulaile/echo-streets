import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

# --- A) Bayer 4x4 表检查 ---
def bayer2(ax, ay):
    v = ax * 0.5 + ay * ay * 0.75
    return v - int(v)

def bayer4(bx, by):
    bx %= 4; by %= 4
    return bayer2(bx, by) + bayer2(bx // 2, by // 2) * 0.25

print('== bayer4 table (should be 16 distinct values 0..0.9375, each once)')
tab = []
for y in range(4):
    row = []
    for x in range(4):
        row.append(bayer4(x, y))
    tab.append(row)
    print('   ' + ' '.join('%.4f' % v for v in row))
flat = sorted(v for r in tab for v in r)
print('   distinct=%d  min=%.4f max=%.4f' % (len(set(flat)), flat[0], flat[-1]))
dup = {}
for v in flat:
    dup[v] = dup.get(v, 0) + 1
print('   counts=%s' % {k: v for k, v in dup.items() if v > 1})

# --- B) 截图是否含扫描线（后期是否已应用） ---
for f in ['ch01_00_player', 'ch01_04_left']:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    ev = od = 0.0
    ne = no = 0
    for y in range(0, h, 2):
        for x in range(w):
            r, g, b = rows[y][x]
            ev += lum(r, g, b); ne += 1
    for y in range(1, h, 2):
        for x in range(w):
            r, g, b = rows[y][x]
            od += lum(r, g, b); no += 1
    print('== %s evenRow=%.2f oddRow=%.2f delta=%.2f%%' % (
        f, ev/ne, od/no, 100.0*(od/no - ev/ne)/(ev/ne)))

# --- C) 右墙 z=0 处的竖直缝：横向扫描一条墙面线 ---
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\ch01_03_right.png')
print('== ch01_03_right y=100 x=0..480 (look for 1-2px notch)')
vals = [(x, lum(*rows[100][x])) for x in range(0, 480)]
base = sum(v for _, v in vals) / len(vals)
notches = [(x, v) for x, v in vals if v < base * 0.85]
print('   base=%.1f  notches=%s' % (base, ['%d:%.0f' % n for n in notches][:20]))

# --- D) 中轴灯带黑线：多张图纵向确认 ---
for f, y0, y1 in [('ch01_00_player', 2, 16), ('ch01_01_center', 2, 16)]:
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    seg = []
    for x in range(225, 258):
        s = 0.0
        for y in range(y0, y1):
            s += lum(*rows[y][x])
        seg.append((x, s/(y1-y0)))
    print('== %s ceiling strip x=225..257' % f)
    print('   ' + ' '.join('%d:%.0f' % t for t in seg))
