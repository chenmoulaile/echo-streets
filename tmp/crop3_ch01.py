import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
import zlib, struct

def write_png(path, w, h, rows):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b = rows[y][x]
            raw += bytes((r, g, b))
    def chunk(typ, data):
        c = struct.pack('>I', len(data)) + typ + data
        c += struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff)
        return c
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)

def crop_scale(src, x0, y0, x1, y1, k, dst):
    w, h, rows = read_png(src)
    cw = (x1 - x0) * k
    ch = (y1 - y0) * k
    out = [[(0, 0, 0)] * cw for _ in range(ch)]
    for y in range(y1 - y0):
        for x in range(x1 - x0):
            px = rows[y0 + y][x0 + x]
            for dy in range(k):
                for dx in range(k):
                    out[y*k + dy][x*k + dx] = px
    write_png(dst, cw, ch, out)
    print('%s -> %s  %dx%d (x=%d..%d y=%d..%d x%d)' % (
        src.split('\\')[-1], dst.split('\\')[-1], cw, ch, x0, x1, y0, y1, k))

S = r'D:\mygame\tmp\shots\chapter\%s.png'
O = r'D:\mygame\tmp\shots\chapter\%s'

# 前台/门（Z-fighting 嫌疑）
crop_scale(S % 'ch01_00_player', 195, 105, 285, 145, 8, O % 'k_reception.png')
# 中轴灯带中段（格栅穿透嫌疑）
crop_scale(S % 'ch01_00_player', 215, 20, 265, 110, 8, O % 'k_strip.png')
# 天花板格栅与灯槽交界
crop_scale(S % 'ch01_01_center', 130, 20, 350, 90, 5, O % 'k_ceiling.png')
# 天空板 + 蓝裙
crop_scale(S % 'ch01_04_left', 20, 40, 200, 200, 5, O % 'k_sky.png')
# 柱础
crop_scale(S % 'ch01_00_player', 85, 140, 135, 180, 10, O % 'k_colbase.png')
# 售货机
crop_scale(S % 'ch01_03_right', 255, 100, 340, 215, 7, O % 'k_vend.png')
