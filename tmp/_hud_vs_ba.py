# -*- coding: utf-8 -*-
from PIL import Image
import os
def stat(p, tag):
    im = Image.open(p).convert("RGBA")
    px = [q for q in im.getdata() if q[3]>40]
    n = len(px)
    dark = sum(1 for q in px if max(q[:3])<70)
    gray = sum(1 for q in px if (max(q[:3])-min(q[:3]))<20)
    sat  = sum(1 for q in px if (max(q[:3])-min(q[:3]))>=60)
    warm = sum(1 for q in px if q[0]>q[2]+18)
    print("%-24s %-9s opaque=%5d  dark=%5.1f%%  gray=%5.1f%%  sat>=60=%5.1f%%  warm=%5.1f%%" % (
        tag, str(im.size), n, dark/n*100, gray/n*100, sat/n*100, warm/n*100))
print("=== 现有两张 HUD 图标（用户要求作废重画）===")
stat(r"D:\mygame\assets\sprites\weapon_pistol_hud.png", "weapon_pistol_hud")
stat(r"D:\mygame\assets\sprites\weapon_shotgun_hud.png", "weapon_shotgun_hud")
print()
print("=== BA 目标参考（纯黑枪）===")
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
for n in ["Weapon_Icon_CH0263.png","Weapon_Icon_13002.png","Weapon_Icon_26002.png"]:
    stat(os.path.join(d,n), n.replace("Weapon_Icon_","").replace(".png",""))
