import struct
import os
import re

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

imp = "assets/sprites/characters/FirstPerson/Handgun/HandgunFire1.png.import"
print("=== import text ===")
txt = blob(imp).decode("utf-8", "replace")
print(txt)

allctex = [x for x in order if x.endswith(".ctex")]
print("\nall ctex:", len(allctex))
hand = [x for x in allctex if "handgun" in x.lower() or "Handgun" in x]
print("handgun ctex:", len(hand), hand[:3])
