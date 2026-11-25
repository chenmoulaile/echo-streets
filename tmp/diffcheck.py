from PIL import Image, ImageChops
import os
O = r"D:\mygame\tmp\shots\chapter_baseline_orig"
N = r"D:\mygame\tmp\shots\chapter_audit"
for n in ["00_player","01_center","02_back","03_right","04_left","05_top"]:
    a = Image.open(os.path.join(O,"ch02_"+n+".png")).convert("RGB")
    b = Image.open(os.path.join(N,"ch02_"+n+".png")).convert("RGB")
    diff = ImageChops.difference(a,b)
    bbox = diff.getbbox()
    px = list(diff.getdata())
    nz = sum(1 for p in px if p!=(0,0,0))
    mx = max(max(p) for p in px)
    print(f"{n}: diffbbox={bbox} changed={nz}/{len(px)} ({nz/len(px)*100:.3f}%) maxdiff={mx}")
    # 隔板区域颜色对比
    for tag,box in [("partition-left",(0,60,140,180)),("meeting-carpet",(330,150,470,240))]:
        ca = a.crop(box); cb = b.crop(box)
        def avg(im):
            d=list(im.getdata()); k=len(d)
            return tuple(round(sum(p[i] for p in d)/k,1) for i in range(3))
        print(f"    {tag}: orig={avg(ca)} new={avg(cb)}")
