from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# ---- 1) 00_player 天花区亮段/暗段（灯是否可读） ----
im = load("ch02_00_player.png")
print("== 00_player 天花 0-100 行：亮段(>=0.88) 与 暗段(<0.45) ==")
for y in range(0,101,4):
    row=[L(im.getpixel((x,y))) for x in range(480)]
    def segs(pred, minlen=6):
        out=[]; s=None
        for x,v in enumerate(row):
            if pred(v):
                if s is None: s=x
            else:
                if s is not None: out.append((s,x-1)); s=None
        if s is not None: out.append((s,479))
        return [g for g in out if g[1]-g[0]>=minlen]
    br = segs(lambda v: v>=0.88); dk = segs(lambda v: v<0.45)
    if br or dk:
        print(f"  y={y:3d} bright={br[:5]} dark={dk[:5]}")

# ---- 2) 8 级色阶量化（模拟 post palette_levels=8 + dither） ----
print()
print("== 8 级量化后的大面积区域 distinct 灰阶数 ==")
def quantize(im, levels=8.0):
    out = Image.new("RGB", im.size)
    px = im.load(); po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r,g,b = px[x,y]
            f = [min(int((c/255.0)*levels + 0.5)/levels*255,255) for c in (r,g,b)]
            po[x,y] = tuple(f)
    return out
for name, box in [("00_player 左侧灰墙",(0,40,120,120)),("04_left 左墙",(180,60,420,140)),
                  ("00_player 天花",(0,0,480,40)),("03_right 天花",(0,0,480,60))]:
    base = "ch02_00_player.png" if name.startswith("00") else "ch02_04_left.png" if name.startswith("04") else "ch02_03_right.png"
    imx = load(base).crop(box)
    q = quantize(imx)
    dc = len(set(q.getdata())); db = len(set(imx.getdata()))
    print(f"  {name:20s} 原 {db} 色 -> 量化后 {dc} 色  区域 {imx.size}")

# ---- 3) 显示器纯蓝确认 ----
print()
print("== 04_left 蓝色像素统计（显示器）==")
im4 = load("ch02_04_left.png")
blues=[]
for y in range(270):
    for x in range(480):
        r,g,b = im4.getpixel((x,y))
        if b>150 and b-r>80 and b-g>80:
            blues.append((x,y,r,g,b))
print(f"  蓝色像素 {len(blues)} 个")
if blues:
    xs=[p[0] for p in blues]; ys=[p[1] for p in blues]
    print(f"  bbox x {min(xs)}-{max(xs)}  y {min(ys)}-{max(ys)}")
    print(f"  样本 {blues[:3]}")
    print(f"  b 均值 {sum(p[4] for p in blues)/len(blues):.0f}  r 均值 {sum(p[2] for p in blues)/len(blues):.0f}")
