import zlib, struct, sys, os

def read_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8
    w = h = bit = ct = None
    idat = b''
    plte = None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos+4])[0]
        typ = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+ln]
        pos += 12 + ln
        if typ == b'IHDR':
            w, h, bit, ct, comp, filt, inter = struct.unpack('>IIBBBBB', chunk)
            assert inter == 0, 'interlaced unsupported'
        elif typ == b'PLTE':
            plte = chunk
        elif typ == b'IDAT':
            idat += chunk
        elif typ == b'IEND':
            break
    raw = zlib.decompress(idat)
    ch = {0:1, 2:3, 3:1, 4:2, 6:4}[ct]
    assert bit == 8, 'bitdepth %d' % bit
    stride = w * ch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(ch, stride):
                line[i] = (line[i] + line[i-ch]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i-ch] if i >= ch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i-ch] if i >= ch else 0
                b = prev[i]
                c = prev[i-ch] if i >= ch else 0
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y*stride:(y+1)*stride] = line
        prev = line
    # to rgb rows
    rows = []
    for y in range(h):
        row = []
        base = y*stride
        for x in range(w):
            o = base + x*ch
            if ct == 3:
                idx = out[o]
                row.append((plte[idx*3], plte[idx*3+1], plte[idx*3+2]))
            elif ct == 0:
                v = out[o]; row.append((v, v, v))
            elif ct == 2:
                row.append((out[o], out[o+1], out[o+2]))
            elif ct == 6:
                row.append((out[o], out[o+1], out[o+2]))
            else:
                v = out[o]; row.append((v, v, v))
        rows.append(row)
    return w, h, rows

def stats(rows, x0, y0, x1, y1):
    n = 0; sr = sg = sb = 0
    mn = 255; mx = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = rows[y][x]
            l = 0.299*r + 0.587*g + 0.114*b
            sr += r; sg += g; sb += b; n += 1
            if l < mn: mn = l
            if l > mx: mx = l
    return (sr/n, sg/n, sb/n, mn, mx)

if __name__ == '__main__':
    pass
