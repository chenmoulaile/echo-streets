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

def proj(p, cam, yaw_deg):
    yaw = math.radians(yaw_deg)
    dx, dy, dz = p[0]-cam[0], p[1]-cam[1], p[2]-cam[2]
    cs, sn = math.cos(yaw), math.sin(yaw)
    # camera forward (yaw 0) = (0,0,-1); right = (1,0,0)
    fwd = (-sn, 0.0, -cs)
    rgt = (cs, 0.0, -sn)
    depth = dx*fwd[0] + dy*fwd[1] + dz*fwd[2]
    if depth <= 0.02:
        return None
    sxw = dx*rgt[0] + dz*rgt[2]
    sx = (sxw/depth)/TH
    sy = (dy/depth)/TV
    return (int(round(W*0.5 + sx*W*0.5)), int(round(H*0.5 - sy*H*0.5)))

def L(c): return (0.299*c[0]+0.587*c[1]+0.114*c[2])/255.0

cam00 = (0.0, 1.6, 15.0)
print("TH=%.4f TV=%.4f" % (TH, TV))
print("="*86)
print("E. PROJECTION of mezzanine members, cam 00 = (0,1.6,15) yaw0")
print("="*86)
probes = [
    ("slab under   x=+9.6 y=2.66 z=+5",  (9.6,2.66,5.0)),
    ("slab under   x=+9.6 y=2.66 z=0",   (9.6,2.66,0.0)),
    ("slab under   x=+9.6 y=2.66 z=-5",  (9.6,2.66,-5.0)),
    ("slab under   x=+9.6 y=2.66 z=-14.6",(9.6,2.66,-14.6)),
    ("slab side    x=+9.6 y=2.94 z=+5",  (9.6,2.94,5.0)),
    ("glass mid    x=+9.6 y=3.42 z=+5",  (9.6,3.42,5.0)),
    ("glass mid    x=+9.6 y=3.42 z=-5",  (9.6,3.42,-5.0)),
    ("handrail     x=+9.6 y=4.03 z=+5",  (9.6,4.03,5.0)),
    ("lightbox     x=+12.94 y=4.20 z=0", (12.94,4.20,0.0)),
    ("lightbox     x=+12.94 y=4.20 z=-12",(12.94,4.20,-12.0)),
    ("lightbox     x=+12.94 y=4.20 z=+12",(12.94,4.20,12.0)),
    ("N slab edge  z=-14.6 y=2.66 x=0",  (0.0,2.66,-14.6)),
    ("N slab side  z=-14.6 y=2.94 x=0",  (0.0,2.94,-14.6)),
    ("N glass      z=-14.6 y=3.42 x=0",  (0.0,3.42,-14.6)),
    ("N handrail   z=-14.6 y=4.03 x=0",  (0.0,4.03,-14.6)),
    ("N wall top   z=-18   y=5.2",       (0.0,5.2,-18.0)),
    ("N wall bot   z=-18   y=0",         (0.0,0.0,-18.0)),
    ("ceiling      z=-18   y=5.2",       (0.0,5.2,-18.0)),
    ("ceiling      z=-5    y=5.2",       (0.0,5.2,-5.0)),
    ("ceiling      z=+5    y=5.2",       (0.0,5.2,5.0)),
    ("floor        z=-5    y=0",         (0.0,0.0,-5.0)),
    ("floor        z=-14.6 y=0",         (0.0,0.0,-14.6)),
]
for name, p in probes:
    r = proj(p, cam00, 0.0)
    if r is None:
        print("  %-36s  behind camera" % name); continue
    x,y = r
    if 0<=x<W and 0<=y<H:
        c = px[x,y]
        print("  %-36s -> (%3d,%3d)  rgb(%3d,%3d,%3d)  L=%.3f" % (name,x,y,c[0],c[1],c[2],L(c)))
    else:
        print("  %-36s -> (%4d,%4d)  OUT OF FRAME" % (name,x,y))

print()
print("="*86)
print("F. column x=409 vertical, y=85..150 (should contain slab/glass/handrail)")
print("="*86)
for y in range(85,151):
    c = px[409,y]
    print("   y=%3d rgb(%3d,%3d,%3d) L=%.3f" % (y,c[0],c[1],c[2],L(c)))
