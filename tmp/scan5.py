from PIL import Image
import os, statistics
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0

im = Image.open(os.path.join(D,"ch02_05_top.png")).convert("RGB")
# 05_top 俯视：找一条横穿左侧工位区但避开桌子的行
print("== 05_top 板缝间距（俯视，无透视畸变）==")
for y in [200, 220, 240]:
    row=[L(im.getpixel((x,y))) for x in range(0,180)]
    mn = min(row); mx=max(row)
    seams=[]
    thr = mn + (mx-mn)*0.35
    for x in range(2,len(row)-2):
        if row[x]<thr and row[x]<=row[x-1] and row[x]<=row[x+1]:
            seams.append(x)
    merged=[]
    for s in seams:
        if merged and s-merged[-1][-1]<=3: merged[-1].append(s)
        else: merged.append([s])
    cents=[round(sum(g)/len(g),1) for g in merged]
    gaps=[round(cents[i+1]-cents[i],1) for i in range(len(cents)-1)]
    print(f"  y={y}: 缝数={len(cents)} 间距={gaps[:14]} 中位={statistics.median(gaps) if gaps else None}")

# 世界尺度换算：05_top 相机在 (0,6.5,21) 朝 -Z pitch -38，地板 y=0
# 视野垂直 75deg -> 视锥中心射线打到地板的距离
import math
cam_y=6.5; pitch=math.radians(-38)
# 射线到地面: t = 6.5 / sin(38)
t = cam_y/math.sin(math.radians(38))
print(f"\n相机到地面落点距离 = {t:.2f} m")
# 480x270, vfov=75 -> 垂直覆盖 = 2*t*tan(37.5)
vcover = 2*t*math.tan(math.radians(37.5))
hcover = vcover*(480/270)
print(f"画面垂直覆盖 {vcover:.2f} m, 水平覆盖 {hcover:.2f} m  -> {hcover/480*100:.1f} cm/px")
print(f"若板缝间距 6px -> 板宽 {6*hcover/480:.3f} m")
