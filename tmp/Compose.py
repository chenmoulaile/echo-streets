"""Compare weapon composition: reference frames vs shipped viewmodel frames.

Reference frames are 1100x452 (2.43 aspect); the game screen is 480x270 (1.78).
Percent-of-width is misleading across aspects, so everything is normalised by
the frame HEIGHT -- that is what reads as "how big the gun looks".
"""
import sys
from PIL import Image


def measure(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    box = im.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
    name = path.split("\\")[-1]
    if box is None:
        print(f"{name:34s} EMPTY")
        return None
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    print(
        f"{name:34s} {w:4d}x{h:<4d} content {bw:4d}x{bh:<4d} "
        f"w/h={bw/bh:5.2f}  w/H={bw/h:5.3f} h/H={bh/h:5.3f} "
        f"x0/H={x0/h:5.3f} x1/H={x1/h:5.3f} cx/H={(x0+x1)/2/h:5.3f} "
        f"bottom={y1 == h}"
    )
    return (x0, y0, x1, y1, w, h)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        measure(p)
