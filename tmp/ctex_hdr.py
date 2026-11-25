import struct
import os

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    data = f.read()

fb = struct.unpack_from("<Q", data, 24)[0]
do = struct.unpack_from("<Q", data, 32)[0]
count = struct.unpack_from("<I", data, do)[0]
p = do + 4
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
    entries[path] = (off, sz, fl)

def blob(path):
    off, sz, fl = entries[path]
    return data[fb + off: fb + off + sz]

targets = [
    ".godot/imported/0001_Handgun.png-0f69ef629ecbaa5b1a92731be988e85b.s3tc.ctex",
    ".godot/imported/HandgunFire1.png-2f333ce03e6d8e4ecf7ee5d6b6d3d69a.bptc.ctex",
]

for t in targets:
    if t not in entries:
        print("MISSING", t)
        continue
    b = blob(t)
    print("===", os.path.basename(t), "size =", len(b))
    print("head hex:", b[:48].hex())
    print("magic:", b[0:4])
    print("u32 @4:", struct.unpack_from("<I", b, 4)[0])
    print("u16 @8,@10:", struct.unpack_from("<H", b, 8)[0], struct.unpack_from("<H", b, 10)[0])
    print("u32 @12:", struct.unpack_from("<I", b, 12)[0])
    print("u32 @16:", struct.unpack_from("<I", b, 16)[0])
    print("u32 @20:", struct.unpack_from("<I", b, 20)[0])
    print("u32 @24:", struct.unpack_from("<I", b, 24)[0])
    print()
