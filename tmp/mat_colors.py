import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

NAMES = ['WhiteWall', 'WhiteWall_Column', 'WhiteCeiling', 'WhiteCeiling_MetalEdge',
         'CeramicFloor_White', 'CeramicFloor_Gray', 'MetalWall', 'MetalPlateWall',
         'WhiteWall_Bottom_Blue', 'WhiteWall_Dirty', 'ExitDoor', 'VendingMachine',
         'Locker_DarkBlue', 'Glass', 'SkyTexture_Sunset']

def lum(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

for n in NAMES:
    p = r'D:\mygame\assets\materials\%s.png' % n
    w, h, rows = read_png(p)
    sr = sg = sb = 0
    n_px = 0
    mns = 999; mxs = -1
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = rows[y][x]
            sr += r; sg += g; sb += b; n_px += 1
            L = lum(r, g, b)
            mns = min(mns, L); mxs = max(mxs, L)
    print('%-24s %dx%d avg=#%02X%02X%02X (%.3f)  contrastRange=%.0f..%.0f' % (
        n, w, h, sr//n_px, sg//n_px, sb//n_px,
        lum(sr/n_px, sg/n_px, sb/n_px)/255.0, mns, mxs))
