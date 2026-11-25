from PIL import Image
import os, glob
d = r"D:\mygame\assets\sprites\viewmodel"
for f in sorted(glob.glob(d+r"\*.png")):
    im = Image.open(f).convert("RGBA")
    cy = 0; n = 0
    for px in im.getdata():
        if px[3] < 40: continue
        n += 1
        r,g,b = px[:3]
        if b > 150 and g > 140 and r < 140: cy += 1
    print(f"{os.path.basename(f):26s} {im.size} opaque={n:6d} cyan={cy:5d} {cy/max(n,1)*100:5.2f}%")
