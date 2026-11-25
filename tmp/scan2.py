from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p):
    r,g,b=p; return (0.2126*r+0.7152*g+0.0722*b)/255.0

# ---- 02_back: 灯槽 vs 发光面 亮度（天花板灯槽位于画面上部） ----
im = Image.open(os.path.join(D,"ch02_02_back.png")).convert("RGB")
w,h = im.size
print("== 02_back 顶部 0-90 行逐行扫描，找灯槽暗/亮结构 ==")
for y in range(0, 95, 3):
    vals=[L(im.getpixel((x,y))) for x in range(0,w,3)]
    print(f"  y={y:3d} min={min(vals):.3f} max={max(vals):.3f} mean={sum(vals)/len(vals):.3f}")

print()
print("== 02_back 灯槽横向剖面（取 y 上最暗行附近，逐列） ==")
# 先找全图最暗的连续区域（灯槽框）
best=None
for y in range(0,90):
    for x in range(0,w,1):
        v=L(im.getpixel((x,y)))
        if best is None or v<best[0]: best=(v,x,y)
print("  最暗像素", best)
