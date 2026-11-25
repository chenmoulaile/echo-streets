from PIL import Image, ImageChops
import os
A = r"D:\mygame\tmp\shots\chapter"
B = r"D:\mygame\tmp\shots\chapter_audit"
names = ["ch02_00_player.png","ch02_01_center.png","ch02_02_back.png","ch02_03_right.png","ch02_04_left.png","ch02_05_top.png"]
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
for n in names:
    a = Image.open(os.path.join(A,n)).convert("RGB")
    b = Image.open(os.path.join(B,n)).convert("RGB")
    d = ImageChops.difference(a,b)
    pa=list(a.getdata()); pb=list(b.getdata())
    ma=sum(L(p) for p in pa)/len(pa); mb=sum(L(p) for p in pb)/len(pb)
    print(f"{n:22s} bbox={str(d.getbbox()):24s} user_mean={ma:.4f} audit_mean={mb:.4f} delta={ma-mb:+.4f}")
