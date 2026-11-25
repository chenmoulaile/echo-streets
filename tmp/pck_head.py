import struct
import sys
import json

PCK = r"D:\mygame\tmp\boomdoa.pck"

with open(PCK, "rb") as f:
    head = f.read(160)

print("hex 0..160:")
for i in range(0, 160, 16):
    chunk = head[i:i + 16]
    hexs = " ".join(f"{b:02x}" for b in chunk)
    asc = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
    print(f"{i:4d}  {hexs:<48}  {asc}")

magic = struct.unpack_from("<I", head, 0)[0]
pack_version = struct.unpack_from("<I", head, 4)[0]
vmaj, vmin, vpatch = struct.unpack_from("<III", head, 8)
flags = struct.unpack_from("<I", head, 20)[0]
print("\nmagic=", head[0:4], "pack_version=", pack_version, "godot=", f"{vmaj}.{vmin}.{vpatch}", "flags=", flags)

# Try both candidate layouts for file_base / dir_offset
for label, fb_off, do_off in (("A: fb@24 do@32", 24, 32), ("B: do@24 fb@32", 32, 24)):
    fb = struct.unpack_from("<Q", head, fb_off)[0]
    do = struct.unpack_from("<Q", head, do_off)[0]
    print(f"{label} -> file_base={fb} dir_offset={do}")

# Layout A assumed by earlier work: file_base=112
fb = struct.unpack_from("<Q", head, 24)[0]
do = struct.unpack_from("<Q", head, 32)[0]
print("\nUsing file_base=", fb, "dir_offset=", do)
print("dir table bytes:", head[do:do + 32].hex() if do < 160 else "(beyond 160, will seek)")
