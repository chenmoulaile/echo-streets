from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# 1) 04_left 蓝色像素
im4 = load("ch02_04_left.png")
blues=[]
for y in range(270):
    for x in range(480):
        r,g,b = im4.getpixel((x,y))
        if b>120 and b-r>60 and b-g>60: blues.append((x,y,r,g,b))
print(f"== 04_left 蓝像素 {len(blues)} 个 ({len(blues)/(480*270)*100:.2f}%) ==")
if blues:
    xs=[p[0] for p in blues]; ys=[p[1] for p in blues]
    print(f"   bbox x {min(xs)}-{max(xs)} y {min(ys)}-{max(ys)}")
    print(f"   mean rgb = ({sum(p[2] for p in blues)/len(blues):.0f},{sum(p[3] for p in blues)/len(blues):.0f},{sum(p[4] for p in blues)/len(blues):.0f})")
    print(f"   样本 {blues[:2]}")

# 2) 05_top 背景色边界
im5 = load("ch02_05_top.png")
BG=(13,15,20)
def nearbg(p,tol=6): return all(abs(p[i]-BG[i])<=tol for i in range(3))
rows=[]
for y in range(270):
    c=sum(1 for x in range(480) if nearbg(im5.getpixel((x,y))))
    rows.append(c)
first = next((y for y,c in enumerate(rows) if c>0), None)
last  = max((y for y,c in enumerate(rows) if c>0), default=None)
print(f"\n== 05_top 背景色(13,15,20) 分布：首行 y={first} 末行 y={last} ==")
for y in [0,20,40,60,70,80,100,120,150,200,269]:
    print(f"   y={y:3d} bgpx={rows[y]:3d} ({rows[y]/480*100:5.1f}%)")
# 左右列
cols=[]
for x in range(480):
    c=sum(1 for y in range(270) if nearbg(im5.getpixel((x,y))))
    cols.append(c)
print(f"   列 x=0 bg={cols[0]}  x=100 bg={cols[100]}  x=240 bg={cols[240]}  x=380 bg={cols[380]}  x=479 bg={cols[479]}")

# 3) 走道：横向剖面找接缝
im0 = load("ch02_00_player.png")
print("\n== 00_player 走道横剖面 y=230，x=180..300 ==")
print("   " + " ".join(f"{im0.getpixel((x,230))[0]:3d}" for x in range(180,301,6)))
print("== 走道纵向 y=200..270 逐行（x=240）==")
print("   " + " ".join(f"{im0.getpixel((240,y))[0]:3d}" for y in range(200,271,5)))
