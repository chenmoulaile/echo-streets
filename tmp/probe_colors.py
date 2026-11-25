from PIL import Image
import os
base = r"D:\mygame\tmp\shots\chapter_audit"
orig = r"D:\mygame\tmp\shots\chapter_baseline_orig"
def stat(p, box=None):
    im = Image.open(p).convert("RGB")
    if box: im = im.crop(box)
    px = list(im.getdata())
    n = len(px)
    r = sum(p[0] for p in px)/n; g = sum(p[1] for p in px)/n; b = sum(p[2] for p in px)/n
    return (round(r,1), round(g,1), round(b,1))

regions = {
 "00_player": [("partition-left",(0,60,140,180)),("floor-wood",(150,180,330,260)),
               ("corridor",(200,200,300,270)),("ceiling",(0,0,480,60)),
               ("far-yellow",(160,60,320,110)),("right-glass",(330,60,480,200))],
 "03_right":  [("table",(100,150,380,270)),("upper-ceiling",(0,0,480,80)),
               ("glassband",(0,80,480,150))],
 "04_left":   [("desk-top",(0,120,480,200)),("partition",(0,40,480,120))],
 "05_top":    [("floor",(100,100,380,250)),("top-edge",(0,0,480,40))],
}
for k, regs in regions.items():
    p = os.path.join(base, k + ".png") if os.path.exists(os.path.join(base,k+".png")) else os.path.join(base, "ch02_"+k+".png")
    if not os.path.exists(p): p = os.path.join(base, "ch02_"+k+".png")
    print("==", k, p)
    for name, box in regs:
        print("   ", name, stat(p, box))
