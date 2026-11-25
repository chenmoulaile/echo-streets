import struct
import os
import re

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    data = f.read()

size = len(data)
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
    md5 = data[p:p + 16]
    p += 16
    fl = struct.unpack_from("<I", data, p)[0]
    p += 4
    entries.append((path, off, sz, fl))

print("total entries:", len(entries))

pngs = [e for e in entries if e[0].lower().endswith(".png")]
print("png entries:", len(pngs))

# weapon-looking names
kw = re.compile(r"(gun|pistol|rifle|shotgun|smg|weapon|hand|arm|view|fps|knife|melee|revolver|magnum|uzi|ak|m4|ammo|bullet|shell)", re.I)
hits = [e for e in pngs if kw.search(e[0])]
print("\n== weapon/hand candidates ==")
for path, off, sz, fl in sorted(hits, key=lambda x: -x[2])[:60]:
    print(f"{sz:>9}  {path}")

print("\n== largest 40 pngs ==")
for path, off, sz, fl in sorted(pngs, key=lambda x: -x[2])[:40]:
    print(f"{sz:>9}  {path}")
