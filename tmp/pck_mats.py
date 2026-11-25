import struct
import re
from collections import Counter

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

def blob(path):
    off, sz, fl = entries[path]
    return data[fb + off: fb + off + sz]

print("== assets/materials (.png.import count by subdir) ==")
mat = [x for x in order if x.startswith("assets/materials/") and x.endswith(".png.import")]
print("total:", len(mat))
for x in sorted(mat):
    print(" ", x.replace("assets/materials/", "").replace(".png.import", ""))

print("\n== assets/sprites subdirs ==")
sp = [x for x in order if x.startswith("assets/sprites/")]
c = Counter("/".join(x.split("/")[:4]) for x in sp)
for k, v in sorted(c.items(), key=lambda z: -z[1]):
    print(f"{v:>5}  {k}")
