import math
from PIL import Image
import os

D = r"D:\mygame\tmp\shots\chapter"
im = Image.open(os.path.join(D, "ch03_00_player.png")).convert("RGB")
px = im.load()
W, H = im.size

FOV = 75.0
TH = math.tan(math.radians(FOV * 0.5))
TV = TH * H / W
print("480x270 fov75 -> TH=%.4f TV=%.4f  (mpp at 1m: %.5f)" % (TH, TV, 2*TH/W))

def proj(p, cam, yaw_deg):
    """world point -> (screen x, screen y) or None"""
    yaw = math.radians(yaw_deg)
    dx = p[0] - cam[0]
    dy = p[1] - cam[1]
    dz = p[2] - cam[2]
    # yaw 0 looks toward -Z. rotate world into camera space
    cs, sn = math.cos(yaw), math.sin(yaw)
    fx = dx * cs - dz * sn      # right
    fz = -dx * sn - dz * cs     # forward = -Z in cam space
    if fz >= -0.01:
        return None
    sx = (fx / (-fz)) / TH
    sy = (dy / (-fz)) / TV
    return (int(round(W * 0.5 + sx * W * 0.5)), int(round(H * 0.5 - sy * H * 0.5)))

cam00 = (0.0, 1.6, 15.0)
print()
print("=" * 78)
print("E. PROJECTION of mezzanine members, camera 00 = (0,1.6,15) yaw0")
print("=" * 78)
probes = [
    ("slab under  x=9.6  z=+5",   (9.6, 2.66, 5.0)),
    ("slab under  x=9.6  z=0",    (9.6, 2.66, 0.0)),
    ("slab under  x=9.6  z=-5",   (9.6, 2.66, -5.0)),
    ("slab side   x=9.6  y=2.80 z=+5", (9.6, 2.80, 5.0)),
    ("slab side   x=9.6  y=2.94 z=+5", (9.6, 2.94, 5.0)),
    ("glass mid   x=9.6  y=3.42 z=+5", (9.6, 3.42, 5.0)),
    ("glass mid   x=9.6  y=3.42 z=-5", (9.6, 3.42, -5.0)),
    ("handrail    x=9.6  y=4.03 z=+5", (9.6, 4.03, 5.0)),
    ("lightbox    x=12.94 y=4.20 z=0", (12.94, 4.20, 0.0)),
    ("lightbox    x=12.94 y=4.20 z=-12", (12.94, 4.20, -12.0)),
    ("N slab edge z=-14.6 y=2.66 x=0", (0.0, 2.66, -14.6)),
    ("N slab side z=-14.6 y=2.94 x=0", (0.0, 2.94, -14.6)),
    ("N glass     z=-14.6 y=3.42 x=0", (0.0, 3.42, -14.6)),
    ("N handrail  z=-14.6 y=4.03 x=0", (0.0, 4.03, -14.6)),
    ("N wall top  z=-18   y=5.2",  (0.0, 5.2, -18.0)),
    ("N wall bot  z=-18   y=0",    (0.0, 0.0, -18.0)),
    ("ceiling     z=-18   y=5.2",  (0.0, 5.2, -18.0)),
    ("ceiling     z=-5    y=5.2",  (0.0, 5.2, -5.0)),
    ("floor       z=-5    y=0",    (0.0, 0.0, -5.0)),
    ("floor       z=-14.6 y=0",    (0.0, 0.0, -14.6)),
]
for name, p in probes:
    r = proj(p, cam00, 0.0)
    if r is None:
        print("  %-34s  off-screen" % name)
        continue
    x, y = r
    if 0 <= x < W and 0 <= y < H:
        c = px[x, y]
        print("  %-34s -> (%3d,%3d)  rgb(%3d,%3d,%3d)  L=%.3f" % (
            name, x, y, c[0], c[1], c[2], (0.299*c[0]+0.587*c[1]+0.114*c[2])/255))
    else:
        print("  %-34s -> (%3d,%3d)  OUT OF FRAME" % (name, x, y))

print()
print("=" * 78)
print("F. VERTICAL SCAN x=409 (mezz inner edge at z=+5), y=80..145")
print("=" * 78)
for y in range(80, 146):
    c = px[409, y]
    print("   y=%3d  rgb(%3d,%3d,%3d)  L=%.3f" % (y, c[0], c[1], c[2],
          (0.299*c[0]+0.587*c[1]+0.114*c[2])/255))

print()
print("=" * 78)
print("G. VERTICAL SCAN x=240 (centre, N mezz edge), y=100..150")
print("=" * 78)
for y in range(100, 151):
    c = px[240, y]
    print("   y=%3d  rgb(%3d,%3d,%3d)  L=%.3f" % (y, c[0], c[1], c[2],
          (0.299*c[0]+0.587*c[1]+0.114*c[2])/255))
