from PIL import Image, ImageDraw
import os
d = r"D:\mygame\tmp\shots\chapter\\"
o = r"D:\mygame\tmp\_ann\\"
os.makedirs(o, exist_ok=True)
for f in ["ch03_00_player.png","ch03_01_center.png","ch03_03_right.png","ch03_05_top.png"]:
    im = Image.open(d+f).convert("RGB")
    s = 2
    im = im.resize((im.width*s, im.height*s), Image.NEAREST)
    dr = ImageDraw.Draw(im)
    for x in range(0, 480, 40):
        dr.line([(x*s,0),(x*s,im.height)], fill=(255,0,0), width=1)
        dr.text((x*s+2, 2), str(x), fill=(255,255,0))
    for y in range(0, 270, 30):
        dr.line([(0,y*s),(im.width,y*s)], fill=(0,255,0), width=1)
        dr.text((2, y*s+2), str(y), fill=(255,255,0))
    im.save(o+f.replace(".png","_grid.png"))
    print("saved", f)
