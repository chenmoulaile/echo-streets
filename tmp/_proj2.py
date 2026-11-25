from PIL import Image
import math

W, H = 480, 270
VFOV = 75.0
TV = math.tan(math.radians(VFOV * 0.5))
TH = TV * (W / float(H))

def project(p, cam, yaw_deg):
    dx, dy, dz = p[0]-cam[0], p[1]-cam[1], p[2]-cam[2]
    a = math.radians(yaw_deg)
    vx =  dx*math.cos(a) + dz*math.sin(a)
    vz = -(-dx*math.sin(a) + dz*math.cos(a))
    vy = dy
    if vz <= 0.01:
        return None
    return (((vx/vz)/TH)*0.5*W + W*0.5, (0.5-(vy/vz)/TV*0.5)*H)

im = Image.open(r"D:\mygame\tmp\shots\chapter\ch03_00_player.png").convert("RGB")
px = im.load()
CAM, YAW = (0.0, 1.6, 15.0), 0.0

print("=== ch03_00 horizontal scans (right half, where mezz inner edge x=+9.6 projects) ===")
for yy in [88, 92, 96, 100, 104, 108, 112, 116, 120, 124, 128]:
    row = []
    for xx in range(300, 480, 20):
        row.append("%3d:%s" % (xx, px[xx, yy]))
    print("  y=%3d " % yy + " ".join(row))

print()
print("=== vertical scan at x=410 (mezz inner edge at z~+5) and x=324 (z~-5) ===")
for xx in [410, 324]:
    print(" x=%d" % xx)
    for yy in range(85, 135, 2):
        r, g, b = px[xx, yy]
        L = (0.299*r+0.587*g+0.114*b)/255.0
        print("   y=%3d rgb=%3d,%3d,%3d L=%.3f" % (yy, r, g, b, L))

print()
print("=== where SHOULD the railing be? project glass top/bottom at x=9.6, z=5 ===")
for label, y in [("slab_bottom 2.66", 2.66), ("slab_top 2.94", 2.94),
                 ("glass_bot 3.095", 3.095), ("glass_mid 3.42", 3.42),
                 ("glass_top 3.745", 3.745), ("handrail 4.03", 4.03)]:
    r = project((9.6, y, 5.0), CAM, YAW)
    sx, sy = int(round(r[0])), int(round(r[1]))
    print("  %-18s -> (%3d,%3d)  rgb=%s" % (label, sx, sy, px[sx, sy]))

print()
print("=== ch03_01_center (0,2.4,0) yaw0: mezz north edge z=-14.6, x=+9.6 ===")
im1 = Image.open(r"D:\mygame\tmp\shots\chapter\ch03_01_center.png").convert("RGB")
px1 = im1.load()
CAM1 = (0.0, 2.4, 0.0)
for label, p in [("NE corner slab bottom", (9.6, 2.66, -14.6)),
                 ("NE railing mid", (9.6, 3.42, -14.6)),
                 ("NE handrail", (9.6, 4.03, -14.6)),
                 ("E railing mid (9.6,3.42,-5)", (9.6, 3.42, -5.0)),
                 ("E railing mid (9.6,3.42,+5)", (9.6, 3.42, 5.0))]:
    r = project(p, CAM1, 0.0)
    if r:
        sx, sy = int(round(r[0])), int(round(r[1]))
        if 0 <= sx < W and 0 <= sy < H:
            print("  %-28s -> (%3d,%3d) rgb=%s" % (label, sx, sy, px1[sx, sy]))
        else:
            print("  %-28s -> (%3d,%3d) OUT" % (label, sx, sy))
