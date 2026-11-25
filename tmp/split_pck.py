import struct
import sys

SRC = r"D:\BOOMDoA 1.10\BOOMDoA.exe"
DST = r"D:\mygame\tmp\boomdoa.pck"

with open(SRC, "rb") as f:
    data = f.read()

size = len(data)
pck_size = struct.unpack_from("<Q", data, size - 12)[0]
start = size - 12 - pck_size
print("exe size =", size)
print("pck_size =", pck_size)
print("start    =", start)
print("magic    =", data[start:start + 4])

with open(DST, "wb") as f:
    f.write(data[start:size - 12])

print("wrote", DST, "bytes =", pck_size)
