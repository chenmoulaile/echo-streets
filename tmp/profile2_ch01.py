import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

def box(f, x0, y0, x1, y1, label):
    w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\%s.png' % f)
    n = 0; s = 0.0; sr = sg = sb = 0; mn = 999; mx = -1
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            L = lum(r, g, b)
            s += L; n += 1; mn = min(mn, L); mx = max(mx, L)
            sr += r; sg += g; sb += b
    print('%-16s %-34s mean=%.0f(%.3f) rgb=(%3d,%3d,%3d) range=%.0f..%.0f' % (
        f, label, s/n, s/n/255.0, sr//n, sg//n, sb//n, mn, mx))

# 出生点近处地板（画面最下沿）
box('ch01_00_player', 40, 250, 180, 270, 'floor bottom-left (near)')
box('ch01_00_player', 300, 250, 440, 270, 'floor bottom-right (near)')
box('ch01_00_player', 190, 250, 290, 270, 'floor bottom-center band')
# 出生点头顶天花（画面最上沿中部）
box('ch01_00_player', 0, 0, 480, 8, 'ceiling very top row')
# 灯阵列：统计天花上灯槽（暗条）的 y 行分布，找灯在画面中的纵向位置
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\ch01_00_player.png')
print('-- ch01_00_player 天花中线 x=240 亮度随 y')
out = []
for y in range(0, 100, 2):
    r, g, b = rows[y][240]
    out.append((y, int(lum(r, g, b))))
print('   ' + ' '.join('%d:%d' % t for t in out))
w, h, rows = read_png(r'D:\mygame\tmp\shots\chapter\ch01_02_back.png')
print('-- ch01_02_back 天花中线 x=240 亮度随 y')
out = []
for y in range(0, 100, 2):
    r, g, b = rows[y][240]
    out.append((y, int(lum(r, g, b))))
print('   ' + ' '.join('%d:%d' % t for t in out))
# 左墙幕墙格：横向扫描蓝色带与橙色格
box('ch01_04_left', 0, 155, 480, 175, 'below-glass band full width')
box('ch01_04_left', 0, 130, 480, 155, 'glass bottom edge')
