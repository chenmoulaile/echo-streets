import struct
import os
import re

PCK = r"D:\mygame\tmp\boomdoa.pck"
OUT = r"D:\mygame\tmp\ctex"

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

# For every FirstPerson .import, read its bptc path and copy that ctex under a clean name.
prefix = "assets/sprites/characters/FirstPerson/"
imports = [x for x in order if x.startswith(prefix) and x.endswith(".png.import")]
print("import files:", len(imports))

copied = 0
missing = 0
names = []
for imp in imports:
    txt = blob(imp).decode("utf-8", "replace")
    m = re.search(r'path\.bptc="res://([^"]+)"', txt)
    if not m:
        missing += 1
        continue
    rel = m.group(1)
    if rel not in entries:
        missing += 1
        continue
    weapon = imp.split("/")[-2]          # Handgun / Shotgun / ...
    frame = os.path.basename(imp)[:-len(".png.import")]
    out_name = f"{weapon}__{frame}.ctex"
    with open(os.path.join(OUT, out_name), "wb") as f:
        f.write(blob(rel))
    names.append(out_name)
    copied += 1

print("copied ctex:", copied, "missing:", missing)
for n in sorted(names)[:20]:
    print(" ", n)
print("  ... total", len(names))
