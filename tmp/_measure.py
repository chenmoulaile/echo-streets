from PIL import Image
import os
d = r"D:\mygame\tmp\shots\chapter"
files = ["ch03_00_player.png","ch03_01_center.png","ch03_02_back.png","ch03_03_right.png","ch03_04_left.png","ch03_05_top.png"]
for f in files:
    im = Image.open(os.path.join(d,f)).convert("RGB")
    w,h = im.size
    px = im.load()
    lum = []
    for y in range(h):
        for x in range(w):
            r,g,b = px[x,y]
            lum.append((0.299*r+0.587*g+0.114*b)/255.0)
    lum_s = sorted(lum)
    n = len(lum_s)
    q = lambda p: lum_s[int(p*(n-1))]
    dark = sum(1 for v in lum_s if v < 0.15)/n
    clip = sum(1 for v in lum_s if v >= 0.985)/n
    print("%s mean=%.3f p1=%.3f p5=%.3f p50=%.3f p95=%.3f max=%.3f  dark<0.15=%.1f%%  clip>=0.985=%.1f%%" % (
        f, sum(lum)/n, q(0.01), q(0.05), q(0.50), q(0.95), lum_s[-1], dark*100, clip*100))
    for ry in range(4):
        row=[]
        for rx in range(6):
            x0=rx*w//6; x1=(rx+1)*w//6; y0=ry*h//4; y1=(ry+1)*h//4
            s=0;c=0
            for y in range(y0,y1):
                for x in range(x0,x1):
                    r,g,b=px[x,y]; s+=(0.299*r+0.587*g+0.114*b)/255.0; c+=1
            row.append(s/c)
        print("   row%d: "%ry + " ".join("%.2f"%v for v in row))
