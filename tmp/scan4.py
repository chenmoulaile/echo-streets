from PIL import Image
import os, colorsys
D = r"D:\mygame\tmp\shots\chapter_audit"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

def sat_stats(im, box, tag):
    x0,y0,x1,y1 = box
    tot=0; ssum=0.0; lsum=0.0; mx=0.0; mn=1.0
    for y in range(y0,y1):
        for x in range(x0,x1):
            r,g,b = im.getpixel((x,y))
            h,l,s = colorsys.rgb_to_hls(r/255,g/255,b/255)
            ssum+=s; lsum+=l; tot+=1
            mx=max(mx,l); mn=min(mn,l)
    print(f"  {tag:26s} sat_mean={ssum/tot:.3f} lum_mean={lsum/tot:.3f} lum_min={mn:.3f} lum_max={mx:.3f}")

im = load("ch02_00_player.png")
print("== 00_player 分区饱和度 ==")
sat_stats(im,(0,0,480,127),"上半(天花+远墙)")
sat_stats(im,(0,127,480,270),"下半(地面+家具)")
sat_stats(im,(200,200,300,270),"中轴走道底部")
sat_stats(im,(0,132,140,200),"左侧木地板近景")
sat_stats(im,(340,132,480,200),"右侧木地板近景")

print()
print("== 05_top 饱和度（全章俯视）==")
im5 = load("ch02_05_top.png")
sat_stats(im5,(0,0,480,270),"全图")
sat_stats(im5,(0,0,480,40),"顶部背景带")

print()
print("== 木地板条宽实测：00_player y=240 一行，找深色缝 ==")
im0 = load("ch02_00_player.png")
y=245
row=[L(im0.getpixel((x,y))) for x in range(480)]
# 缝 = 局部极小
seams=[]
for x in range(2,478):
    if row[x]<row[x-1] and row[x]<=row[x+1] and row[x] < 0.62:
        seams.append(x)
# 合并相邻
merged=[]
for s in seams:
    if merged and s-merged[-1][-1]<=2: merged[-1].append(s)
    else: merged.append([s])
cents=[sum(g)/len(g) for g in merged]
print("  缝中心 x:", [round(c,1) for c in cents])
if len(cents)>1:
    gaps=[round(cents[i+1]-cents[i],1) for i in range(len(cents)-1)]
    print("  缝间距(px):", gaps)
    import statistics
    print("  中位间距(px):", statistics.median(gaps))
