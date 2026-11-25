from PIL import Image
import os
def scan(p):
    im = Image.open(p).convert("RGBA")
    n = 0; cy = 0; cyhi = 0
    for px in im.getdata():
        if px[3] < 40: continue
        n += 1
        r,g,b = px[:3]
        if b > 150 and g > 140 and r < 140: cy += 1
    print(f"{os.path.basename(p):32s} size={im.size} opaque={n} cyanish={cy} ({cy/max(n,1)*100:.1f}%)")
for p in [r"D:\mygame\assets\sprites\weapon_pistol_hud.png", r"D:\mygame\assets\sprites\weapon_shotgun_hud.png"]:
    scan(p)
print("--- viewmodel frames ---")
d = r"D:\mygame\assets\sprites\viewmodel"
for f in sorted(os.listdir(d))[:6]:
    if f.endswith(".png"): scan(os.path.join(d,f))
