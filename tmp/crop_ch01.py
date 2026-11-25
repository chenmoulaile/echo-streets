import zlib, struct, sys
sys.path.insert(0, r'D:\mygame\tmp')
from probe_ch01_px import read_png

def write_png(path, rows):
    h = len(rows); w = len(rows[0])
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for (r, g, b) in rows[y]:
            raw += bytes((r, g, b))
    def chunk(typ, data):
        c = struct.pack('>I', len(data)) + typ + data
        return c + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff)
    out = b'\x89PNG\r\n\x1a\n'
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    out += chunk(b'IEND', b'')
    open(path, 'wb').write(out)

def crop_scale(rows, x0, y0, x1, y1, k):
    out = []
    for y in range(y0, y1):
        line = []
        for x in range(x0, x1):
            line.extend([rows[y][x]] * k)
        for _ in range(k):
            out.append(line)
    return out

if __name__ == '__main__':
    src, dst, x0, y0, x1, y1, k = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:8])
    w, h, rows = read_png(src)
    write_png(dst, crop_scale(rows, x0, y0, x1, y1, k))
    print('ok', dst)
