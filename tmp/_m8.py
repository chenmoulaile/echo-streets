from PIL import Image
from collections import Counter
d = r"D:\mygame\tmp\shots\chapter\\"
def L(p): return (0.299*p[0]+0.587*p[1]+0.114*p[2])/255.0

im = Image.open(d+"ch03_00_player.png").convert("RGB"); px=im.load()
print("=== ch03_00 天花量化直方图 (x 60..420, y 0..70) ===")
c = Counter()
for y in range(0,70):
    for x in range(60,420):
        c[px[x,y]] += 1
for rgb,n in c.most_common(14):
    print("  rgb=%s n=%5d L=%.4f  *8=%.2f" % (rgb,n,L(rgb),L(rgb)*8))

print()
print("=== ch03_00 店面以上横带 (x 20..180, y 95..135) ===")
s=0;n=0
for y in range(95,136):
    for x in range(20,181):
        s+=L(px[x,y]); n+=1
print("  mean L=%.3f" % (s/n))
print("=== 同高右侧 (x 300..460, y 95..135) ===")
s=0;n=0
for y in range(95,136):
    for x in range(300,461):
        s+=L(px[x,y]); n+=1
print("  mean L=%.3f" % (s/n))
print("=== 天花正中 (x 150..330, y 0..60) ===")
s=0;n=0
for y in range(0,61):
    for x in range(150,331):
        s+=L(px[x,y]); n+=1
print("  mean L=%.3f" % (s/n))

im3 = Image.open(d+"ch03_03_right.png").convert("RGB"); p3=im3.load()
print()
print("=== ch03_03 深色大块采样 (x 380..460, y 145..185) ===")
c=Counter()
for y in range(145,186):
    for x in range(380,461):
        c[p3[x,y]]+=1
for rgb,n in c.most_common(6):
    print("  rgb=%s n=%d L=%.3f" % (rgb,n,L(rgb)))

im2 = Image.open(d+"ch03_02_back.png").convert("RGB"); p2=im2.load()
print()
print("=== ch03_02 中央列 x=236..246, y=240 ===")
for x in range(232,252):
    r,g,b=p2[x,240]; print("  x=%d rgb=(%d,%d,%d) L=%.3f"%(x,r,g,b,L((r,g,b))))
