from PIL import Image
d = r"D:\mygame\tmp\shots\chapter\\"
o = r"D:\mygame\tmp\_crop\\"
import os
os.makedirs(o, exist_ok=True)
jobs = [
 ("ch03_03_right.png",(0,60,240,200),"a_shop_left.png",3),
 ("ch03_03_right.png",(240,60,480,200),"b_shop_right.png",3),
 ("ch03_01_center.png",(0,80,200,160),"c_wall_left.png",4),
 ("ch03_00_player.png",(150,200,330,270),"d_floor_seam.png",4),
 ("ch03_05_top.png",(0,0,480,230),"e_top.png",2),
 ("ch03_00_player.png",(300,100,480,170),"f_right_band.png",4),
]
for src,box,out,scale in jobs:
    im = Image.open(d+src).convert("RGB").crop(box)
    im = im.resize((im.width*scale, im.height*scale), Image.NEAREST)
    im.save(o+out)
    print(out, im.size)
