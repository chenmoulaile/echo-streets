# -*- coding: utf-8 -*-
from PIL import Image
import os, collections
def pal(p, n=10, tag=""):
    im = Image.open(p).convert("RGBA")
    px = [q[:3] for q in im.getdata() if q[3] > 40]
    if not px: 
        print(tag, "EMPTY"); return
    t = Image.new("RGB",(len(px),1)); t.putdata(px)
    q = t.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pl = q.getpalette()[:n*3]; cnt = collections.Counter(q.getdata())
    print("%s  %s  opaque=%d" % (tag, im.size, len(px)))
    for idx,c in cnt.most_common(n):
        r,g,b = pl[idx*3:idx*3+3]
        L = (r*299+g*587+b*114)//1000
        sat = max(r,g,b)-min(r,g,b)
        print("    %5.1f%%  rgb(%3d,%3d,%3d)  L=%3d sat=%3d" % (c/len(px)*100, r,g,b, L, sat))

print("=== 现有 viewmodel 帧（用户要全废的两张代表）===")
pal(r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png", 10, "vm_pistol_idle")
pal(r"D:\mygame\assets\sprites\viewmodel\vm_shotgun_idle.png", 10, "vm_shotgun_idle")
print()
print("=== 现有 HUD 图标（同样要全废）===")
pal(r"D:\mygame\assets\sprites\weapon_pistol_hud.png", 8, "weapon_pistol_hud")
pal(r"D:\mygame\assets\sprites\weapon_shotgun_hud.png", 8, "weapon_shotgun_hud")
