import struct, glob, os
for p in sorted(glob.glob(r'D:\mygame\assets\materials\*.png')):
    d = open(p, 'rb').read(33)
    w, h = struct.unpack('>II', d[16:24])
    bit = d[24]; ct = d[25]
    print(f"{os.path.basename(p):45s} {w:5d}x{h:<5d} bit{bit} ct{ct}")
