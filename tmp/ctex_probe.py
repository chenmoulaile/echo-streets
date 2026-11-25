import struct
import os

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    data = f.read()

fb = struct.unpack_from("<Q", data, 24)[0]
do = struct.unpack_from("<Q", data, 32)[0]
count = struct.unpack_from("<I", data, do)[0]
p = do + 4
entries = {}
order = []
for _ in range(count):
    plen = struct.unpack_from("<I", data, p)[0]
    p += 4
    path = data[p:p + plen].rstrip(b"\x00").decode("utf-8", "replace")
    p += plen
    off, sz = struct.unpack_from("<QQ", data, p)
    p += 16
    p += 16
    fl = struct.unpack_from("<I", data, p)[0]
    p += 4
    entries[path] = (off, sz, fl)
    order.append(path)

ctex = [x for x in order if x.endswith(".ctex") and "FirstPerson" in x]
print("ctex count:", len(ctex))

s = ctex[0]
off, sz, fl = entries[s]
b = data[fb + off: fb + off + sz]
print("sample:", s, "size:", sz)
print("head hex:", b[:48].hex())

# header per Godot: magic GST2, version u32, w u16, h u16, flags u32, mipmap_count u32
magic = b[0:4]
ver = struct.unpack_from("<I", b, 4)[0]
w = struct.unpack_from("<H", b, 8)[0]
h = struct.unpack_from("<H", b, 10)[0]
flags = struct.unpack_from("<I", b, 12)[0]
print(f"magic={magic} ver={ver} w={w} h={h} flags={flags:#x}")

# locate embedded PNG / WEBP / JPEG
PNG = b"\x89PNG\r\n\x1a\n"
RIFF = b"RIFF"
WEBP = b"WEBP"
JPEG = b"\xff\xd8\xff"

def find_all(hay, needle, limit=4):
    out = []
    i = hay.find(needle)
    while i >= 0 and len(out) < limit:
        out.append(i)
        i = hay.find(needle, i + 1)
    return out

print("PNG at:", find_all(b, PNG))
print("WEBP at:", find_all(b, WEBP))
print("RIFF at:", find_all(b, RIFF))
print("JPEG at:", find_all(b, JPEG))
print("GST2 count:", b.count(b"GST2"))
