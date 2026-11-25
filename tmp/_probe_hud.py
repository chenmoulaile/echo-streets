import sys
from PIL import Image
for p in [r"D:\mygame\assets\sprites\weapon_pistol_hud.png", r"D:\mygame\assets\sprites\weapon_shotgun_hud.png"]:
    im = Image.open(p).convert("RGBA")
    print(p, im.size)
    cols = {}
    for px in im.getdata():
        if px[3] < 40: continue
        cols[px[:3]] = cols.get(px[:3], 0) + 1
    for c, n in sorted(cols.items(), key=lambda kv: -kv[1])[:14]:
        print("   ", c, n)
