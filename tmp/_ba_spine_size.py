# -*- coding: utf-8 -*-
from PIL import Image
import os
# BA spine 图集里找手部/袖口区域：直接看一张角色立绘图集的尺寸与内容规模
for name in ["justice_normal1_spr","helmetdan_black1_spr","fuuki_normal1_spr"]:
    p = r"D:\Bluearchive\repo\resources\spine\%s\%s.png" % (name,name)
    if os.path.exists(p):
        im = Image.open(p)
        print("%-26s %s %s %.1fKB" % (name, im.size, im.mode, os.path.getsize(p)/1024))
    else:
        print("%-26s MISSING" % name)
