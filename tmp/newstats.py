from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
names = ["ch02_00_player.png","ch02_01_center.png","ch02_02_back.png","ch02_03_right.png","ch02_04_left.png","ch02_05_top.png"]
print("== 最新基线（22:43:00）逐帧统计 ==")
for n in names:
    im = Image.open(os.path.join(D,n)).convert("RGB")
    px = list(im.getdata()); N=len(px)
    ls = [L(p) for p in px]
    mean = sum(ls)/N
    hi = sum(1 for v in ls if v>=0.98)/N*100
    hi95 = sum(1 for v in ls if v>=0.95)/N*100
    dk = sum(1 for v in ls if v<0.15)/N*100
    dk02 = sum(1 for v in ls if v<0.02)/N*100
    print(f"{n:22s} mean={mean:.3f} >=0.98:{hi:5.2f}% >=0.95:{hi95:5.2f}% <0.15:{dk:5.2f}% <0.02:{dk02:5.2f}% distinct={len(set(px))}")

print()
print("== 3x3 分区亮度 ==")
for n in names:
    im = Image.open(os.path.join(D,n)).convert("RGB")
    grid=[]
    for j in range(3):
        row=[]
        for i in range(3):
            box=(i*160,j*90,(i+1)*160,(j+1)*90)
            c=im.crop(box); d=list(c.getdata())
            row.append(round(sum(L(p) for p in d)/len(d),3))
        grid.append(row)
    print(f"{n:22s} {grid}")
