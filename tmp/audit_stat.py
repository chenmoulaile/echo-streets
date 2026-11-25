import os, math, json
from PIL import Image
D=r"D:\mygame\tmp\shots\chapter"
names=["ch02_00_player","ch02_01_center","ch02_02_back","ch02_03_right","ch02_04_left","ch02_05_top"]
def lum(p):
    r,g,b=p[0]/255.0,p[1]/255.0,p[2]/255.0
    return 0.2126*r+0.7152*g+0.0722*b
for n in names:
    p=os.path.join(D,n+".png")
    im=Image.open(p).convert("RGB")
    W,H=im.size
    px=list(im.getdata())
    L=[lum(q) for q in px]
    mean=sum(L)/len(L)
    clip=sum(1 for v in L if v>=0.98)/len(L)
    clip95=sum(1 for v in L if v>=0.95)/len(L)
    dead=sum(1 for v in L if v<0.15)/len(L)
    black=sum(1 for v in L if v<0.02)/len(L)
    cols=len(set(px))
    # region grid 3x3
    grid=[]
    for ry in range(3):
        row=[]
        for rx in range(3):
            x0=rx*W//3; x1=(rx+1)*W//3
            y0=ry*H//3; y1=(ry+1)*H//3
            s=[lum(im.getpixel((x,y))) for y in range(y0,y1) for x in range(x0,x1)]
            row.append(round(sum(s)/len(s),3))
        grid.append(row)
    print(f"== {n}  {W}x{H}")
    print(f"   mean={mean:.3f} clip>=0.98={clip*100:.2f}% clip>=0.95={clip95*100:.2f}% dead<0.15={dead*100:.2f}% black<0.02={black*100:.2f}% colors={cols}")
    print(f"   grid(rows top->bottom, cols L->R): {grid}")
