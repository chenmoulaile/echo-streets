"""裁一小块图放大，用来看清 viewmodel / UI 细节。
   py -3 tmp/Crop.py <src> <x> <y> <w> <h> <scale> <dst>
"""
import sys
from PIL import Image

src, x, y, w, h, scale, dst = sys.argv[1:8]
im = Image.open(src).convert("RGB")
out = im.crop((int(x), int(y), int(x) + int(w), int(y) + int(h)))
out = out.resize((out.width * int(scale), out.height * int(scale)), Image.NEAREST)
out.save(dst)
print("[crop] %s %dx%d -> %s" % (dst, out.width, out.height, dst))
