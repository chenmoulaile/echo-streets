from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# ---------- Q1 灯具发光面亮度：02_back 顶部找亮斑 ----------
im = load("ch02_02_back.png")
print("== 02_back 顶部 0-60 行：每 2 行找最亮连续段（灯具发光面应 ~0.95+）==")
for y in range(0,60,2):
    row=[L(im.getpixel((x,y))) for x in range(480)]
    # 找 >=0.85 的段
    segs=[]; s=None
    for x,v in enumerate(row):
        if v>=0.85:
            if s is None: s=x
        else:
            if s is not None: segs.append((s,x-1)); s=None
    if s is not None: segs.append((s,479))
    segs=[g for g in segs if g[1]-g[0]>=4]
    if segs:
        print(f"  y={y:2d} bright segs {segs[:6]}  max={max(row):.3f}")
print()
print("== 02_back 天花板暗斑定位（<0.45）==")
for y in range(0,60,2):
    row=[L(im.getpixel((x,y))) for x in range(480)]
    segs=[]; s=None
    for x,v in enumerate(row):
        if v<0.45:
            if s is None: s=x
        else:
            if s is not None: segs.append((s,x-1)); s=None
    if s is not None: segs.append((s,479))
    segs=[g for g in segs if g[1]-g[0]>=4]
    if segs: print(f"  y={y:2d} dark segs {segs[:8]}")
