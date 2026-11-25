"""Measure every BOOM reference first-person frame: bbox + union, so a common crop
can be chosen for the whole animation set (frames are full-screen overlays and are
already aligned to each other -- cropping each to its own bbox would make the gun
jump between frames).
"""
import glob
import os
from PIL import Image


def bbox(path):
    im = Image.open(path).convert("RGBA")
    return im.size, im.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()


def scan(pattern):
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"  (no match: {pattern})")
        return
    ux0 = uy0 = 10**9
    ux1 = uy1 = -1
    size = None
    print(f"--- {pattern} ({len(files)} files)")
    for f in files:
        size, b = bbox(f)
        if b is None:
            print(f"  {os.path.basename(f):44s} EMPTY")
            continue
        ux0, uy0 = min(ux0, b[0]), min(uy0, b[1])
        ux1, uy1 = max(ux1, b[2]), max(uy1, b[3])
        print(f"  {os.path.basename(f):44s} {b[0]:4d},{b[1]:3d} - {b[2]:4d},{b[3]:3d}"
              f"  {b[2]-b[0]:4d}x{b[3]-b[1]:<4d}")
    print(f"  UNION {ux0},{uy0} - {ux1},{uy1}  {ux1-ux0}x{uy1-uy0}"
          f"  canvas={size}  aspect={(ux1-ux0)/(uy1-uy0):.3f}")
    return (ux0, uy0, ux1, uy1), size


scan(r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png")
scan(r"D:\mygame\tmp\fp_png\Handgun__HandgunFire*.png")
scan(r"D:\mygame\tmp\fp_png\Handgun__Handgun_Reload*.png")
scan(r"D:\mygame\tmp\fp_png\Handgun__HandgunDraw*.png")
scan(r"D:\mygame\tmp\fp_png\Handgun__HandgunDry*.png")
scan(r"D:\mygame\tmp\fp_png\Shotgun__ShotgunIdle.png")
scan(r"D:\mygame\tmp\fp_png\Shotgun__ShotgunFire*.png")
scan(r"D:\mygame\tmp\fp_png\Shotgun__ShotgunReload*.png")
scan(r"D:\mygame\tmp\fp_png\Shotgun__ShotgunDraw*.png")
