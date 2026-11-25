from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

im0 = load("ch02_00_player.png")
print("== 00_player 远端黄墙带：逐行找 R-B 峰值 ==")
for y in range(100,150,2):
    row=[im0.getpixel((x,y)) for x in range(120,360,6)]
    rb=[p[0]-p[2] for p in row]
    print(f"  y={y:3d} meanR-B={sum(rb)/len(rb):6.1f} maxR-B={max(rb):4d} rgb_sample={row[len(row)//2]}")

print()
print("== 00_player 黄墙区域精确取样 (x=200-280, y=118-128) ==")
c=im0.crop((200,118,280,128)); d=list(c.getdata()); n=len(d)
print(f"  mean=({sum(p[0] for p in d)/n:.0f},{sum(p[1] for p in d)/n:.0f},{sum(p[2] for p in d)/n:.0f}) R-B={sum(p[0] for p in d)/n - sum(p[2] for p in d)/n:.0f}")

im2 = load("ch02_02_back.png")
print()
print("== 02_back 显示器蓝块 ==")
bl=[]
for y in range(270):
    for x in range(480):
        r,g,b=im2.getpixel((x,y))
        if b-r>40 and b>60: bl.append((x,y,r,g,b))
print(f"  数量={len(bl)} ({len(bl)/(480*270)*100:.2f}%)")
if bl:
    xs=[p[0] for p in bl]; ys=[p[1] for p in bl]
    print(f"  bbox x{min(xs)}-{max(xs)} y{min(ys)}-{max(ys)} mean=({sum(p[2] for p in bl)/len(bl):.0f},{sum(p[3] for p in bl)/len(bl):.0f},{sum(p[4] for p in bl)/len(bl):.0f})")
    print(f"  最大b = {max(p[4] for p in bl)}")

im5 = load("ch02_05_top.png")
print()
print("== 05_top 显示器蓝块 ==")
bl=[]
for y in range(270):
    for x in range(480):
        r,g,b=im5.getpixel((x,y))
        if b-r>40 and b>60: bl.append((x,y,r,g,b))
print(f"  数量={len(bl)} ({len(bl)/(480*270)*100:.2f}%)")
if bl:
    xs=[p[0] for p in bl]; ys=[p[1] for p in bl]
    print(f"  bbox x{min(xs)}-{max(xs)} y{min(ys)}-{max(ys)} mean=({sum(p[2] for p in bl)/len(bl):.0f},{sum(p[3] for p in bl)/len(bl):.0f},{sum(p[4] for p in bl)/len(bl):.0f})")

print()
print("== 05_top 会议室的短边玻璃是否接到右墙 x=12 ==")
# 房间2 z=-1..4；右墙 x=12 在 05_top 里的屏幕位置
print("  俯视 6.0cm/px, 画面中心 x=240 对应世界 x=0 -> 世界 x=12 在屏幕 x=240+200=440")
for yy in [95,100,105,110]:
    row=[im5.getpixel((x,yy)) for x in range(400,479,4)]
    print(f"  y={yy} " + " ".join(f"{p[0]:3d}" for p in row))
