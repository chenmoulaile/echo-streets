import os
from PIL import Image
D=r"D:\mygame\tmp\shots\chapter"
def lum(p): return 0.2126*p[0]/255+0.7152*p[1]/255+0.0722*p[2]/255
def stats(im,box,label):
    x0,y0,x1,y1=box
    px=[im.getpixel((x,y)) for y in range(y0,y1) for x in range(x0,x1)]
    L=[lum(q) for q in px]
    n=len(L)
    hist={}
    for v in L:
        k=round(v*255)
        hist[k]=hist.get(k,0)+1
    top=sorted(hist.items(), key=lambda kv:-kv[1])[:6]
    print(f"  {label} box={box} n={n} mean={sum(L)/n:.3f} min={min(L):.3f} max={max(L):.3f}")
    print(f"    top5 levels: {[(k, round(c/n*100,1)) for k,c in top]}")
    # distinct levels
    print(f"    distinct={len(hist)}")

im=Image.open(os.path.join(D,"ch02_00_player.png")).convert("RGB")
print("== ch02_00_player ==")
stats(im,(0,180,480,270),"lower band (wood floor near)")
stats(im,(200,200,300,270),"center corridor bottom")
stats(im,(0,0,480,60),"ceiling band")
stats(im,(0,60,140,180),"left desks mid")

im=Image.open(os.path.join(D,"ch02_05_top.png")).convert("RGB")
print("== ch02_05_top ==")
stats(im,(0,0,480,40),"top band")
stats(im,(0,0,60,270),"left band")
stats(im,(420,0,480,270),"right band")
stats(im,(150,90,330,200),"floor center")

im=Image.open(os.path.join(D,"ch02_03_right.png")).convert("RGB")
print("== ch02_03_right ==")
stats(im,(0,150,480,270),"lower (conference table)")
stats(im,(0,0,480,80),"ceiling upper")
stats(im,(60,80,260,150),"glass region")

im=Image.open(os.path.join(D,"ch02_04_left.png")).convert("RGB")
print("== ch02_04_left ==")
stats(im,(0,120,480,200),"desk surface band")
stats(im,(0,0,480,70),"upper wall/ceiling")
