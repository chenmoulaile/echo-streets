from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# ---------- A: 03_right 会议桌 / 会议室内部 / 天花 ----------
im3 = load("ch02_03_right.png")
def stat(im,box,tag):
    c=im.crop(box); d=list(c.getdata()); n=len(d)
    ls=[L(p) for p in d]
    print(f"  {tag:30s} mean={sum(ls)/n:.3f} min={min(ls):.3f} max={max(ls):.3f} rgbmean=({sum(p[0] for p in d)/n:.0f},{sum(p[1] for p in d)/n:.0f},{sum(p[2] for p in d)/n:.0f})")
print("== 03_right 分区 ==")
stat(im3,(60,190,300,270),"会议桌台面")
stat(im3,(0,150,60,270),"会议桌左缘/地面")
stat(im3,(150,80,470,150),"会议室后墙")
stat(im3,(0,0,480,80),"天花(上半)")
stat(im3,(300,150,480,270),"右侧玻璃/地面")

# ---------- B: 04_left 显示器 / 桌面 ----------
im4 = load("ch02_04_left.png")
print()
print("== 04_left 蓝像素(显示器) ==")
blues=[]
for y in range(270):
    for x in range(480):
        r,g,b=im4.getpixel((x,y))
        if b>110 and b-r>60 and b-g>60: blues.append((x,y,r,g,b))
xs=[p[0] for p in blues]; ys=[p[1] for p in blues]
print(f"  数量={len(blues)} bbox x{min(xs)}-{max(xs)} y{min(ys)}-{max(ys)} mean=({sum(p[2] for p in blues)/len(blues):.0f},{sum(p[3] for p in blues)/len(blues):.0f},{sum(p[4] for p in blues)/len(blues):.0f})")
# 蓝块正下方的竖直剖面，找桌面顶边
cx=(min(xs)+max(xs))//2
print(f"  蓝块中心 x={cx} 竖直剖面 y={min(ys)-12}..{max(ys)+40}")
print("   " + " ".join(f"{y}:{im4.getpixel((cx,y))[0]}" for y in range(min(ys)-12, max(ys)+41, 4)))
stat(im4,(0,60,480,190),"左墙大片")
stat(im4,(0,190,480,270),"下半(桌面/地面)")
stat(im4,(0,0,480,60),"天花")

# ---------- C: 00_player 天花与灯 ----------
im0 = load("ch02_00_player.png")
print()
print("== 00_player 天花 0-90 行逐行 min/max/mean ==")
for y in range(0,92,6):
    row=[L(im0.getpixel((x,y))) for x in range(480)]
    print(f"  y={y:2d} min={min(row):.3f} max={max(row):.3f} mean={sum(row)/480:.3f}")
print("== 走道 vs 木地板 ==")
stat(im0,(200,220,290,270),"中轴走道")
stat(im0,(20,200,150,270),"左侧木地板")
stat(im0,(330,200,470,270),"右侧木地板")
