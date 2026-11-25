from PIL import Image
d = r"D:\mygame\tmp\shots\chapter\\"
def L(p): return (0.299*p[0]+0.587*p[1]+0.114*p[2])/255.0
def sat(p):
    mx=max(p); mn=min(p)
    return 0 if mx==0 else (mx-mn)/mx

im = Image.open(d+"ch03_00_player.png").convert("RGB"); px=im.load()
print("=== ch03_00 x=240 y=108..142 二层应出现区 ===")
for y in range(108,143):
    r,g,b=px[240,y]
    print("  y=%3d rgb=(%3d,%3d,%3d) L=%.3f S=%.2f"%(y,r,g,b,L((r,g,b)),sat((r,g,b))))
print()
print("=== ch03_00 远端墙 z=-18 底部 (x=240, y=136..152) 找蓝色墙裙 ===")
for y in range(136,153):
    r,g,b=px[240,y]
    print("  y=%3d rgb=(%3d,%3d,%3d) L=%.3f S=%.2f"%(y,r,g,b,L((r,g,b)),sat((r,g,b))))
