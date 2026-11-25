from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# 1) 00_player 逐行平均，定位远端黄墙的真实 y 带
im = load("ch02_00_player.png"); w,h = im.size
print("== 00_player 行平均（每 6 行）==")
for y in range(0,h,6):
    row = [im.getpixel((x,y)) for x in range(0,w,4)]
    n=len(row); r=sum(p[0] for p in row)/n; g=sum(p[1] for p in row)/n; b=sum(p[2] for p in row)/n
    print(f"  y={y:3d}  rgb=({r:5.1f},{g:5.1f},{b:5.1f})  R-B={r-b:5.1f}")

# 2) 黄色像素统计（R-B>25）
def yellow_stats(n):
    im=load(n); w,h=im.size; tot=w*h; c=0; ys=[]
    for y in range(h):
        for x in range(w):
            r,g,b=im.getpixel((x,y))
            if r-b>25 and r>90:
                c+=1; ys.append(y)
    return c, tot, (min(ys) if ys else None, max(ys) if ys else None)
for n in ["ch02_00_player.png","ch02_01_center.png","ch02_02_back.png","ch02_03_right.png","ch02_04_left.png","ch02_05_top.png"]:
    c,t,rng = yellow_stats(n)
    print(f"{n}: yellow px {c} ({c/t*100:.2f}%)  y-range {rng}")
