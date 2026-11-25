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

sample = "assets/sprites/characters/FirstPerson/Handgun/HandgunFire1_a.png.import"
print("=== " + sample + " ===")
print(blob(sample).decode("utf-8", "replace"))

print("\n=== sibling .remap? ===")
for cand in (sample.replace(".import", ".remap"), sample.replace(".png.import", ".remap")):
    print(cand, "->", cand in entries)

print("\n=== any .remap for FirstPerson ===")
rm = [x for x in order if x.startswith("assets/sprites/characters/FirstPerson/") and x.endswith(".remap")]
print(len(rm), rm[:5])

print("\n=== a .godot/imported sample from FirstPerson ===")
gi = [x for x in order if x.startswith(".godot/imported/") and "handgun" in x.lower()][:5]
print(gi)
