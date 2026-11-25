r"""把 viewmodel 全帧拼成对照图，用于目视检查落位与帧间差异。

用法: py -3 tmp/VmSheet.py <kind> [scale]
输出: D:\mygame\tmp\shots\_vmsheet2.png
"""
import glob
import os
import sys

from PIL import Image

kind = sys.argv[1] if len(sys.argv) > 1 else "pistol"
scale = int(sys.argv[2]) if len(sys.argv) > 2 else 2
files = sorted(glob.glob(r"D:\mygame\assets\sprites\viewmodel\vm_%s_*.png" % kind))
print("frames:", [os.path.basename(f) for f in files])
ims = [Image.open(f).convert("RGBA") for f in files]
w = max(i.width for i in ims)
h = max(i.height for i in ims)
cols = 5
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGBA", (w * cols * scale, h * rows * scale), (26, 30, 44, 255))
for i, im in enumerate(ims):
    r, c = divmod(i, cols)
    big = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
    sheet.paste(big, (c * w * scale, r * h * scale), big)
dst = r"D:\mygame\tmp\shots\_vmsheet2.png"
sheet.save(dst)
print("[sheet] %s %dx%d %dB" % (dst, sheet.width, sheet.height, os.path.getsize(dst)))
