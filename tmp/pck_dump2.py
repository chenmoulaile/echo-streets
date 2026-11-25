import struct

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
    raw = data[p:p + plen]
    path = raw.rstrip(b"\x00").decode("utf-8", "replace")
    p += plen
    off, sz = struct.unpack_from("<QQ", data, p)
    p += 16
    p += 16
    fl = struct.unpack_from("<I", data, p)[0]
    p += 4
    entries[path] = (off, sz, fl)
    order.append(path)

hits = [x for x in order if "HandgunFire1" in x]
print("hits:", hits)

def blob(path):
    off, sz, fl = entries[path]
    return data[fb + off: fb + off + sz]

if hits:
    s = hits[0]
    print("=== " + s + " ===")
    print(blob(s).decode("utf-8", "replace")[:1500])
