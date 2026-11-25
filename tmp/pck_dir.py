import struct
import os

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    data = f.read()

size = len(data)
print("pck file size =", size)

fb = struct.unpack_from("<Q", data, 24)[0]
do = struct.unpack_from("<Q", data, 32)[0]
print("file_base =", fb, "dir_offset =", do)

def parse_dir(base, file_base):
    if base + 4 > size:
        return None
    count = struct.unpack_from("<I", data, base)[0]
    if count <= 0 or count > 100000:
        return None
    entries = []
    p = base + 4
    try:
        for _ in range(count):
            plen = struct.unpack_from("<I", data, p)[0]
            p += 4
            if plen <= 0 or plen > 4096:
                return None
            path = data[p:p + plen].decode("utf-8", "replace")
            p += plen
            off, sz = struct.unpack_from("<QQ", data, p)
            p += 16
            md5 = data[p:p + 16]
            p += 16
            fl = struct.unpack_from("<I", data, p)[0]
            p += 4
            entries.append((path, off, sz, fl))
    except struct.error:
        return None
    return entries

candidates = {
    "dir_offset absolute": do,
    "dir_offset + file_base": do + fb,
    "size-12-dir_offset": size - 12 - do,
}
for label, base in candidates.items():
    res = parse_dir(base, fb)
    if res is None:
        print(f"{label}: base={base} -> PARSE FAIL")
    else:
        print(f"{label}: base={base} -> {len(res)} entries; first 3 = {res[:3]}")
