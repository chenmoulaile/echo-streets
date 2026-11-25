from PIL import Image
d = r"D:\mygame\tmp\shots\chapter\\"
def L(p): return (0.299*p[0]+0.587*p[1]+0.114*p[2])/255.0

print("=== ch03_01 逐行 (x=240) y=100..150 : 二层结构应在 y=113..131 ===")
im = Image.open(d+"ch03_01_center.png").convert("RGB"); px=im.load()
for y in range(100,152,2):
    r,g,b=px[240,y]; print("  y=%3d rgb=(%3d,%3d,%3d) L=%.3f"%(y,r,g,b,L((r,g,b))))

print()
print("=== ch03_05 逐行 (x=240) y=60..230 : 南侧环廊顶面应在 y=103..178 ===")
im5 = Image.open(d+"ch03_05_top.png").convert("RGB"); p5=im5.load()
for y in range(60,232,6):
    r,g,b=p5[240,y]; print("  y=%3d rgb=(%3d,%3d,%3d) L=%.3f"%(y,r,g,b,L((r,g,b))))

print()
print("=== ch03_05 横向 (y=140) 看左右是否出现楼板 ===")
for x in range(0,480,20):
    r,g,b=p5[x,140]; print("  x=%3d rgb=(%3d,%3d,%3d) L=%.3f"%(x,r,g,b,L((r,g,b))))
