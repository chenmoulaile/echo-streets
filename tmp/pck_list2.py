import struct
import re

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    data = f.read()

fb = struct.unpack_from("<Q", data, 24)[0]
do = struct.unpack_from("<Q", data, 32)[0]
count = struct.unpack_from("<I", data, do)[0]
p = do + 4
entries = []
for _ in range(count):
    plen = struct.unpack_from("<I", data, p)[0]
    p += 4
    path = data[p:p + plen].decode("utf-8", "replace").rstrip("\x00")
    p += plen
    off, sz = struct.unpack_from("<QQ", data, p)
    p += 16
    p += 16
    fl = struct.unpack_from("<I", data, p)[0]
    p += 4
    entries.append((path, off, sz, fl))

def bucket(path):
    parts = path.split("/")
    if len(parts) >= 2:
        return "/".join(parts[:2])
    return path

from collections import Counter
c = Counter(bucket(e[0]) for e in entries)
print("== buckets ==")
for k, v in sorted(c.items(), key=lambda x: -x[1]):
    print(f"{v:>5}  {k}")

kw = re.compile(r"(gun|pistol|rifle|shotgun|smg|weapon|hand|arm|view|fps|knife|melee|revolver|magnum|ammo|bullet|shell|hoshino|star)", re.I)
hits = [e for e in entries if kw.search(e[0]) and e[0].startswith("assets/")]
print("\n== weapon/hand candidates (assets/) ==")
for path, off, sz, fl in sorted(hits, key=lambda x: -x[2])[:80]:
    print(f"{sz:>9}  {path}")

print("\n== top-level assets/sprites sample ==")
sp = [e for e in entries if e[0].startswith("assets/sprites/") and not e[0].startswith("assets/sprites/menu")]
print("count:", len(sp))
for path, off, sz, fl in sorted(sp, key=lambda x: -x[2])[:40]:
    print(f"{sz:>9}  {path}")
