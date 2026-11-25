# -*- coding: utf-8 -*-
from PIL import Image
import os, glob
# BA 角色半身像：量制服/袖口配色，作为"默认学生手臂"参考
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-01_character-_mxload"
picks = ["NPC_Portrait_Justice_normal1.png","NPC_Portrait_Fuuki_Normal1.png",
         "NPC_Portrait_Helmetdan_Black1.png","NPC_Portrait_GenbuStore_SG.png"]
for n in picks:
    p = os.path.join(d,n)
    if not os.path.exists(p): continue
    im = Image.open(p).convert("RGBA")
    px = [q for q in im.getdata() if q[3]>40]
    if not px: continue
    tot=len(px)
    # 白衬衫：高明度低饱和
    shirt = sum(1 for q in px if (q[0]*299+q[1]*587+q[2]*114)//1000 > 200 and max(q[:3])-min(q[:3]) < 40)
    # 深色外套：低明度
    dark  = sum(1 for q in px if max(q[:3]) < 80)
    # 皮肤
    skin  = sum(1 for q in px if q[0]-q[2] > 25 and q[0] > 150)
    print("%-34s %s  shirt=%4.1f%% dark=%4.1f%% skin=%4.1f%%" % (n, im.size, shirt/tot*100, dark/tot*100, skin/tot*100))
