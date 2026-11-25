from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")
def stat(im,box,tag):
    c=im.crop(box); d=list(c.getdata()); n=len(d)
    ls=[L(p) for p in d]
    print(f"  {tag:28s} mean={sum(ls)/n:.3f} min={min(ls):.3f} max={max(ls):.3f} rgb=({sum(p[0] for p in d)/n:.0f},{sum(p[1] for p in d)/n:.0f},{sum(p[2] for p in d)/n:.0f})")

im4 = load("ch02_04_left.png")
print("== 04_left 蓝像素（阈值 b-r>40）==")
blues=[]
for y in range(270):
    for x in range(480):
        r,g,b=im4.getpixel((x,y))
        if b-r>40 and b>80: blues.append((x,y,r,g,b))
print(f"  数量={len(blues)}")
if blues:
    xs=[p[0] for p in blues]; ys=[p[1] for p in blues]
    print(f"  bbox x{min(xs)}-{max(xs)} y{min(ys)}-{max(ys)} mean=({sum(p[2] for p in blues)/len(blues):.0f},{sum(p[3] for p in blues)/len(blues):.0f},{sum(p[4] for p in blues)/len(blues):.0f})")
    print(f"  饱和度样本 {blues[:3]}")
print()
stat(im4,(0,60,480,190),"左墙大片")
stat(im4,(0,190,480,270),"下半(桌面/地面)")
stat(im4,(0,0,480,60),"天花")
stat(im4,(180,140,240,250),"显示器所在")

im0 = load("ch02_00_player.png")
print()
print("== 00_player 天花 0-90 行 ==")
for y in range(0,92,6):
    row=[L(im0.getpixel((x,y))) for x in range(480)]
    print(f"  y={y:2d} min={min(row):.3f} max={max(row):.3f} mean={sum(row)/480:.3f}")
print("== 走道 vs 木地板 ==")
stat(im0,(200,220,290,270),"中轴走道")
stat(im0,(20,200,150,270),"左侧木地板")
stat(im0,(330,200,470,270),"右侧木地板")
stat(im0,(0,110,480,150),"远端黄墙带")

im2 = load("ch02_02_back.png")
print()
print("== 02_back ==")
stat(im2,(0,0,480,40),"天花顶部(灯)")
stat(im2,(0,120,200,270),"左侧玻璃会议室")
stat(im2,(280,120,480,270),"右侧工位")
