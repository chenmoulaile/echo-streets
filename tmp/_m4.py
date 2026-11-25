import math, os
from PIL import Image

D = r"D:\mygame\tmp\shots\chapter"
SHOTS = ["ch03_00_player","ch03_01_center","ch03_02_back",
         "ch03_03_right","ch03_04_left","ch03_05_top"]

def L(c): return (0.299*c[0]+0.587*c[1]+0.114*c[2])/255.0

print("="*80)
print("H. PURE-WHITE (255,255,255) clipping")
print("="*80)
for s in SHOTS:
    im = Image.open(os.path.join(D,s+".png")).convert("RGB"); px = im.load(); W,H = im.size
    xs,ys,cnt = [],[],0
    for y in range(H):
        for x in range(W):
            if px[x,y]==(255,255,255):
                cnt+=1; xs.append(x); ys.append(y)
    if cnt:
        print("%-16s pure255=%5d (%.2f%%)  bbox x=%d..%d y=%d..%d" % (s,cnt,cnt/(W*H)*100,min(xs),max(xs),min(ys),max(ys)))
    else:
        print("%-16s pure255=0" % s)

print()
print("="*80)
print("I. any channel at 255")
print("="*80)
for s in SHOTS:
    im = Image.open(os.path.join(D,s+".png")).convert("RGB"); px=im.load(); W,H=im.size
    cnt=0
    for y in range(H):
        for x in range(W):
            if max(px[x,y])==255: cnt+=1
    print("%-16s any255=%5d (%.2f%%)" % (s,cnt,cnt/(W*H)*100))

print()
print("="*80)
print("J. HORIZONTAL scan y=250 across centre guide band (seam hunt)")
print("="*80)
for s in ["ch03_00_player","ch03_02_back"]:
    im = Image.open(os.path.join(D,s+".png")).convert("RGB"); px=im.load()
    print(s)
    for y in (250,200,170):
        row=[]
        for x in range(200,281,2):
            c=px[x,y]
            row.append("%d:%d" % (x,int(L(c)*100)))
        print("  y=%d  "%y + " ".join(row))

print()
print("="*80)
print("K. CEILING vs FLOOR luminance, matched screen regions (shot 00)")
print("="*80)
im = Image.open(os.path.join(D,"ch03_00_player.png")).convert("RGB"); px=im.load()
def region(x0,x1,y0,y1):
    tot=0;n=0;mx=0;mn=1
    for y in range(y0,y1):
        for x in range(x0,x1):
            v=L(px[x,y]); tot+=v;n+=1;mx=max(mx,v);mn=min(mn,v)
    return tot/n,mn,mx
for name,(x0,x1,y0,y1) in {
    "ceiling near  (x180..300 y10..50)":(180,300,10,50),
    "ceiling mid   (x180..300 y50..80)":(180,300,50,80),
    "back wall     (x180..300 y105..125)":(180,300,105,125),
    "floor near    (x180..300 y200..255)":(180,300,200,255),
    "floor mid     (x180..300 y160..200)":(180,300,160,200),
    "guide band    (x230..250 y200..255)":(230,250,200,255),
    "left shopfront(x20..120  y110..150)":(20,120,110,150),
    "right shopfront(x360..470 y110..150)":(360,470,110,150),
    "mezz band L   (x340..420 y100..126)":(340,420,100,126),
    "mezz band R   (x60..140  y100..126)":(60,140,100,126),
}.items():
    m,mn,mx = region(x0,x1,y0,y1)
    print("  %-38s mean=%.3f min=%.3f max=%.3f" % (name,m,mn,mx))

print()
print("="*80)
print("L. SHOPFRONT SIGN BAND — shot 03, columns of the sign row")
print("="*80)
im = Image.open(os.path.join(D,"ch03_03_right.png")).convert("RGB"); px=im.load()
for y in range(100,140,3):
    row=[]
    for x in range(20,470,30):
        c=px[x,y]; row.append("%3d" % int(L(c)*100))
    print("  y=%3d  "%y + " ".join(row))
print()
print("  saturation map (max-min)/max*100 on same grid:")
for y in range(100,140,4):
    row=[]
    for x in range(20,470,30):
        c=px[x,y]; mx=max(c); mn=min(c)
        s = 0 if mx==0 else int((mx-mn)/mx*100)
        row.append("%3d" % s)
    print("  y=%3d  "%y + " ".join(row))

print()
print("="*80)
print("M. TOP SHOT geometry check: camera (0,6.5,21), room z in [-18,18], y in [0,5.2]")
print("="*80)
cam=(0.0,6.5,21.0); pitch=math.radians(-38.0)
TH=math.tan(math.radians(37.5)); TV=TH*270/480
print("  camera y=6.5 > ceiling 5.2  -> %.1f m above ceiling" % (6.5-5.2))
print("  camera z=21.0 > south wall 18 -> %.1f m outside room" % (21.0-18.0))
for sy in (0,135,227,228,269):
    ang = pitch - math.atan(((sy-135)/135.0)*TV)
    print("  screen y=%3d -> pitch %.2f deg ; horizontal ray from y=6.5 hits y=5.2 at z=%.2f, y=0 at z=%.2f" % (
        sy, math.degrees(ang), 21.0-(6.5-5.2)/math.tan(-ang), 21.0-(6.5-0.0)/math.tan(-ang)))
