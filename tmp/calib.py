from PIL import Image
import os, math
D = r"D:\mygame\tmp\shots\chapter"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
im5 = Image.open(os.path.join(D,"ch02_05_top.png")).convert("RGB")

# 走道 CeramicFloor_White 亮 (211,210,215)，木地板 (167,131,96)
# 用 G 通道区分：走道 G~210，木地板 G~131
print("== 05_top 中轴走道屏幕宽度标定（走道世界宽 2.4 m）==")
for y in [120,150,180,210,240,260]:
    row=[im5.getpixel((x,y)) for x in range(480)]
    # 走道: G>190 且 |R-G|<12
    xs=[x for x,p in enumerate(row) if p[1]>185 and abs(p[0]-p[1])<14 and abs(p[2]-p[1])<16]
    if xs:
        # 取包含 x=240 的连续段
        seg=[x for x in xs if abs(x-240)<200]
        w = max(seg)-min(seg)+1
        print(f"  y={y:3d} 走道 x {min(seg)}-{max(seg)} 宽 {w} px -> {240/w*100:.2f} cm/px")
