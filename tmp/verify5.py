from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

im0 = load("ch02_00_player.png")
print("== 00_player 走道纵向剖面 x=240, y=190..269 ==")
print("   " + " ".join(f"{im0.getpixel((240,y))[0]:3d}" for y in range(190,270,4)))
print("== 走道横向 y=250, x=150..330 ==")
print("   " + " ".join(f"{im0.getpixel((x,250))[0]:3d}" for x in range(150,331,6)))

# 03_right 玻璃区：找深青(0,93,123)系像素
im3 = load("ch02_03_right.png")
teal=[]
for y in range(270):
    for x in range(480):
        r,g,b=im3.getpixel((x,y))
        if abs(r-0)<60 and 70<g<130 and 100<b<160 and b>g+15:
            teal.append((x,y,r,g,b))
print(f"\n== 03_right 深青(玻璃边框色) 像素 {len(teal)} ({len(teal)/(480*270)*100:.2f}%) ==")
if teal:
    xs=[p[0] for p in teal]; ys=[p[1] for p in teal]
    print(f"   bbox x {min(xs)}-{max(xs)} y {min(ys)}-{max(ys)}")
    print(f"   样本 {teal[:3]}")

# 03_right 高亮条纹（>0.85）位置
print("\n== 03_right 高亮条纹(>=0.85) 逐行 ==")
for y in range(0,180,10):
    row=[L(im3.getpixel((x,y))) for x in range(480)]
    segs=[]; s=None
    for x,v in enumerate(row):
        if v>=0.85:
            if s is None: s=x
        else:
            if s is not None: segs.append((s,x-1)); s=None
    if s is not None: segs.append((s,479))
    segs=[g for g in segs if g[1]-g[0]>=3]
    if segs: print(f"  y={y:3d} {segs[:8]}")
