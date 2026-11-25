import struct
import os
import re

PCK = r"D:\mygame\tmp\boomdoa.pck"
OUT = r"D:\mygame\tmp\ctex_char"

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

os.makedirs(OUT, exist_ok=True)
prefix = "assets/sprites/characters/"
imports = [x for x in order if x.startswith(prefix) and x.endswith(".png.import") and "/FirstPerson/" not in x]
print("character imports:", len(imports))

copied = 0
for imp in imports:
    txt = blob(imp).decode("utf-8", "replace")
    m = re.search(r'path\.\w+="res://([^"]+\.ctex)"', txt)
    if not m:
        continue
    rel = m.group(1)
    if rel not in entries:
        continue
    name = imp[len(prefix):].replace("/", "__").replace(".png.import", "")
    with open(os.path.join(OUT, name + ".ctex"), "wb") as f:
        f.write(blob(rel))
    copied += 1
print("copied:", copied)
