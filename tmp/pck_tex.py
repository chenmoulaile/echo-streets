import struct
import os
import re
import json

PCK = r"D:\mygame\tmp\boomdoa.pck"
OUT = r"D:\mygame\tmp\ref_tex"

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
    path = data[p:p + plen].decode("utf-8", "replace").rstrip("\x00")
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

targets = [p for p in order if p.startswith("assets/sprites/characters/FirstPerson/")]
print("FirstPerson .import entries:", len(targets))

os.makedirs(OUT, exist_ok=True)
mapping = {}
for imp in targets:
    txt = blob(imp).decode("utf-8", "replace")
    m = re.search(r'dest_files=\[(.*?)\]', txt, re.S)
    if not m:
        continue
    dests = re.findall(r'"([^"]+)"', m.group(1))
    for d in dests:
        if d.endswith(".ctex"):
            rel = d.replace("res://", "")
            mapping[imp] = rel

print("mapped:", len(mapping))

# extract ctex
done = 0
for imp, rel in mapping.items():
    if rel not in entries:
        continue
    name = os.path.basename(imp).replace(".png.import", "")
    sub = imp.split("/")[-2]
    outdir = os.path.join(OUT, sub)
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, name + ".ctex"), "wb") as f:
        f.write(blob(rel))
    done += 1

print("extracted ctex:", done)
for sub in sorted(set(k.split("/")[-2] for k in mapping)):
    n = len([k for k in mapping if k.split("/")[-2] == sub])
    print(f"  {sub}: {n}")
