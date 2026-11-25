from PIL import Image
import math

W, H = 480, 270
VFOV = 75.0
ASPECT = W / float(H)
TV = math.tan(math.radians(VFOV * 0.5))          # 0.7673
TH = TV * ASPECT                                  # 1.3641

def project(p, cam, yaw_deg):
    """Godot: yaw=0 -> forward -Z, right +X, up +Y."""
    dx, dy, dz = p[0]-cam[0], p[1]-cam[1], p[2]-cam[2]
    a = math.radians(yaw_deg)
    # rotate world into view space (yaw about Y)
    vx =  dx*math.cos(a) + dz*math.sin(a)
    vz = -dx*math.sin(a) + dz*math.cos(a)
    vz = -vz
    vy = dy
    if vz <= 0.01:
        return None
    ndc_x = (vx/vz)/TH
    ndc_y = (vy/vz)/TV
    return ((ndc_x*0.5+0.5)*W, (0.5-ndc_y*0.5)*H)

CAM = (0.0, 1.6, 15.0)
YAW = 0.0
HALF_W, HALF_L, MEZZ = 13.0, 18.0, 2.8
band = 3.4
ix, iz = HALF_W-band, HALF_L-band

print("=== projected landmarks, ch03_00 player cam (0,1.6,15) yaw 0 ===")
pts = {
 "mezz_inner_edge_bottom (9.6,2.66,5)": (9.6, 2.66, 5.0),
 "mezz_inner_edge_bottom (9.6,2.66,-5)": (9.6, 2.66, -5.0),
 "railing_glass_mid (9.6,3.42,5)": (9.6, 3.42, 5.0),
 "railing_glass_mid (9.6,3.42,-5)": (9.6, 3.42, -5.0),
 "railing_top (9.6,3.895,5)": (9.6, 3.895, 5.0),
 "railing_top (9.6,3.895,-5)": (9.6, 3.895, -5.0),
 "handrail (9.6,4.03,5)": (9.6, 4.03, 5.0),
 "mezz_N_slab_inner (0,2.66,-14.6)": (0.0, 2.66, -14.6),
 "mezz_N_slab_inner_top (0,2.94,-14.6)": (0.0, 2.94, -14.6),
 "mezz_N_railing_mid (0,3.42,-14.6)": (0.0, 3.42, -14.6),
 "mezz_N_handrail (0,4.03,-14.6)": (0.0, 4.03, -14.6),
 "lightbox (12.94,4.2,0)": (12.94, 4.2, 0.0),
 "lightbox (12.94,4.2,-12)": (12.94, 4.2, -12.0),
 "sign_left (12.62,2.05,-3)": (-12.62, 2.05, -3.0),
 "sign_left (12.62,2.05,9)": (-12.62, 2.05, 9.0),
 "shop_window_top_left (-12.92,2.10,9)": (-12.92, 2.10, 9.0),
 "N_wall_bottom (0,0,-18)": (0.0, 0.0, -18.0),
 "N_wall_top (0,5.2,-18)": (0.0, 5.2, -18.0),
}
for k, v in pts.items():
    r = project(v, CAM, YAW)
    print("  %-40s %s" % (k, "OFFSCREEN" if r is None else "(%.0f, %.0f)" % r))

print()
print("=== ch03_00: sample along the mezzanine inner-edge line (x=9.6, z 6..-6) ===")
im = Image.open(r"D:\mygame\tmp\shots\chapter\ch03_00_player.png").convert("RGB")
px = im.load()
for z in [6.0, 4.0, 2.0, 0.0, -2.0, -4.0, -6.0]:
    for label, y in [("slab_bottom", 2.66), ("railing", 3.42), ("railing_top", 3.895)]:
        r = project((9.6, y, z), CAM, YAW)
        if r is None:
            continue
        sx, sy = int(r[0]), int(r[1])
        if 0 <= sx < W and 0 <= sy < H:
            print("   z=%5.1f %-12s -> (%3d,%3d) rgb=%s" % (z, label, sx, sy, px[sx, sy]))
        else:
            print("   z=%5.1f %-12s -> (%3d,%3d) OUT" % (z, label, sx, sy))

print()
print("=== ch03_00: horizontal scan y=103 and y=116 (where the mezz inner edge should be) ===")
for yy in [103, 110, 116, 120]:
    row = []
    for xx in range(380, 481, 10):
        row.append("%3d:%s" % (xx, px[xx, yy]))
    print("  y=%3d " % yy + " ".join(row))

print()
print("=== curvature black-border extent (shader enable_crt=true, curvature=0.06) ===")
def is_black_by_curvature(u, v, amount=0.06):
    cx, cy = u*2-1, v*2-1
    s = 1.0 + amount*(cx*cx+cy*cy)*0.5
    return (cx*s < -1.0) or (cx*s > 1.0) or (cy*s < -1.0) or (cy*s > 1.0)
for name, uv in [("bottom-center (0.5,0.001)", (0.5, 0.001)),
                 ("bottom-center (0.5,0.01)", (0.5, 0.01)),
                 ("bottom-center (0.5,0.02)", (0.5, 0.02)),
                 ("bottom-center (0.5,0.03)", (0.5, 0.03)),
                 ("top-center (0.5,0.999)", (0.5, 0.999)),
                 ("corner (0.001,0.001)", (0.001, 0.001)),
                 ("left-center (0.001,0.5)", (0.001, 0.5)),
                 ("mid-bottom (0.5,0.05)", (0.5, 0.05))]:
    print("   %-28s black=%s" % (name, is_black_by_curvature(*uv)))

print()
print("=== ch03_05: camera is OUTSIDE the room? ===")
print("   cam = player_start(0,0,15) + (0,6.5,6) = (0, 6.5, 21)")
print("   room south wall z=+18  -> cam z=21 is 3.0 m OUTSIDE")
print("   ceiling y=5.2          -> cam y=6.5 is 1.3 m ABOVE the ceiling")
print("   bottom ray depression = 38 + 37.5 = 75.5 deg -> floor hit at 6.5/tan(75.5)=%.2f m in front" % (6.5/math.tan(math.radians(75.5))))
print("   => nearest floor seen is z = 21 - %.2f = %.2f  (room ends at z=18)" % (6.5/math.tan(math.radians(75.5)), 21-6.5/math.tan(math.radians(75.5))))
