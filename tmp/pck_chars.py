import struct
from collections import Counter
import re

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    data = f.read()

fb = struct.unpack_from("<Q", data, 24)[0]
do = struct.unpack_from("<Q", data, 32)[0]
count = struct.unpack_from("<I", data, do)[0]
p = do + 4
order = []
entries = {}
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
    order.append(path)
    entries[path] = (off, sz, fl)

for who in ("Rabu", "Droid", "Sweeper", "Helmet_AR"):
    pre = f"assets/sprites/characters/{who}/"
    imps = [x for x in order if x.startswith(pre) and x.endswith(".png.import")]
    print(f"\n== {who}: {len(imps)} png.import ==")
    names = sorted(x.replace(pre, "").replace(".png.import", "") for x in imps)
    # group by stripping trailing digits
    groups = Counter(re.sub(r"\d+$", "", n) for n in names)
    for k, v in sorted(groups.items()):
        print(f"   {v:>3}  {k}*")
    print("   sample:", names[:6])
