from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# 天花暗斑：00_player 天花带 y0-30（最远天花，无灯）
im0 = load("ch02_00_player.png")
print("== 00_player 天花 y=8 横剖面（找 AO 斑块起伏）==")
row=[L(im0.getpixel((x,8))) for x in range(480)]
print("   " + " ".join(f"{int(v*255):3d}" for v in row[::12]))
vals=sorted(row)
print(f"   min={row and min(row):.3f} p10={vals[48]:.3f} p50={vals[240]:.3f} p90={vals[432]:.3f} max={max(row):.3f} 动态范围={max(row)-min(row):.3f}")

print()
print("== 02_back 天花 y=30-80（灯下）==")
im2 = load("ch02_02_back.png")
for y in [30,40,50,60,70,80]:
    row=[L(im2.getpixel((x,y))) for x in range(480)]
    vals=sorted(row)
    print(f"  y={y:2d} min={min(row):.3f} p10={vals[48]:.3f} p50={vals[240]:.3f} p90={vals[432]:.3f} max={max(row):.3f}")

print()
print("== 03_right 天花 y=0-70 ==")
im3 = load("ch02_03_right.png")
for y in [0,10,20,30,40,50,60,70]:
    row=[L(im3.getpixel((x,y))) for x in range(480)]
    vals=sorted(row)
    print(f"  y={y:2d} min={min(row):.3f} p10={vals[48]:.3f} p50={vals[240]:.3f} p90={vals[432]:.3f} max={max(row):.3f}")

print()
print("== 04_left 左墙 x 剖面 y=100 ==")
im4 = load("ch02_04_left.png")
row=[L(im4.getpixel((x,100))) for x in range(480)]
print("   " + " ".join(f"{int(v*255):3d}" for v in row[::12]))
vals=sorted(row)
print(f"   min={min(row):.3f} p10={vals[48]:.3f} p50={vals[240]:.3f} p90={vals[432]:.3f} max={max(row):.3f}")
