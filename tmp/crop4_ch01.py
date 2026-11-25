import sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png
import zlib, struct

def write_png(path, w, h, rows):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r,g,b = rows[y][x]
            raw += bytes((r,g,b))
    def chunk(t,d):
        c = struct.pack('>I', len(d)) + t + d
        c += struct.pack('>I', zlib.crc32(t+d)&0xffffffff)
        return c
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w,h,8,2,0,0,0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw),6))
    png += chunk(b'IEND', b'')
    open(path,'wb').write(png)

def crop_scale(src,x0,y0,x1,y1,k,dst):
    w,h,rows = read_png(src)
    cw=(x1-x0)*k; ch=(y1-y0)*k
    out=[[(0,0,0)]*cw for _ in range(ch)]
    for y in range(y1-y0):
        for x in range(x1-x0):
            px=rows[y0+y][x0+x]
            for dy in range(k):
                for dx in range(k):
                    out[y*k+dy][x*k+dx]=px
    write_png(dst,cw,ch,out)
    print('%s -> %s %dx%d' % (src.split('\\')[-1], dst.split('\\')[-1], cw, ch))

S = r'D:\mygame\tmp\shots\chapter\%s.png'
O = r'D:\mygame\tmp\shots\chapter\%s'
crop_scale(S%'ch01_00_player', 200, 8, 290, 100, 7, O%'n_top.png')
crop_scale(S%'ch01_00_player', 180, 110, 300, 155, 8, O%'n_far.png')
crop_scale(S%'ch01_01_center', 140, 55, 350, 105, 6, O%'n_beam.png')
crop_scale(S%'ch01_03_right', 130, 195, 350, 235, 6, O%'n_skirt.png')
crop_scale(r'D:\mygame\assets\materials\sky_window.png', 0, 0, 3860, 520, 1, O%'n_skyfull.png')
