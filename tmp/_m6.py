from PIL import Image
d = r"D:\mygame\tmp\shots\chapter\\"
def L(p): return (0.299*p[0]+0.587*p[1]+0.114*p[2])/255.0
im = Image.open(d+"ch03_00_player.png").convert("RGB"); px=im.load()
print("== ch03_00 天花区 (x 60..200, y 0..70) ==")
s=0;c=0
for y in range(0,70):
    for x in range(60,200):
        s+=L(px[x,y]); c+=1
print("   ceiling mean L=%.3f" % (s/c))
print("== ch03_00 天花区 (x 280..420, y 0..70) ==")
s=0;c=0
for y in range(0,70):
    for x in range(280,420):
        s+=L(px[x,y]); c+=1
print("   ceiling mean L=%.3f" % (s/c))
print("== ch03_00 侧墙 (x 30..90, y 120..160) ==")
s=0;c=0
for y in range(120,160):
    for x in range(30,90):
        s+=L(px[x,y]); c+=1
print("   wall mean L=%.3f" % (s/c))
print("== ch03_00 远端墙 z=-18 (x 200..280, y 118..135) ==")
s=0;c=0
for y in range(118,135):
    for x in range(200,280):
        s+=L(px[x,y]); c+=1
print("   far wall mean L=%.3f" % (s/c))
print("== ch03_00 远端墙底部 0..1.1m 应无墙裙 (x 200..280, y 128..140) ==")
for y in range(126,142,2):
    print("   y=%d L=%.3f" % (y, L(px[240,y])))
