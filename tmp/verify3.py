from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

im = load("ch02_00_player.png")
print("== 00_player y=30..48, x=165..315 采样（x=0,z=12 那盏灯的位置）==")
for y in range(28,50,2):
    row=[]
    for x in range(165,320,10):
        p=im.getpixel((x,y)); row.append(f"{p[0]:3d}")
    print(f"  y={y:2d} " + " ".join(row))
print()
print("== 该区域颜色统计 ==")
box=(171,34,309,44)
crop=im.crop(box); d=list(crop.getdata()); n=len(d)
print("  mean rgb =", tuple(round(sum(p[i] for p in d)/n,1) for i in range(3)))
print("  max  rgb =", tuple(max(p[i] for p in d) for i in range(3)))
print("  distinct =", len(set(d)))
# 最亮像素
best=max(((L(p),p,x,y) for y in range(box[1],box[3]) for x in range(box[0],box[2]) for p in [im.getpixel((x,y))]))
print("  最亮像素:", best)

print()
print("== 02_back y=0..20 x=140..340 同区域（回望，应看到 z=18 灯）==")
im2 = load("ch02_02_back.png")
for y in range(0,22,2):
    row=[]
    for x in range(140,345,12):
        p=im2.getpixel((x,y)); row.append(f"{p[0]:3d}")
    print(f"  y={y:2d} " + " ".join(row))
