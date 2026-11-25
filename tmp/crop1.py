from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
O = r"D:\mygame\tmp\crops"
os.makedirs(O, exist_ok=True)

def crop(src, box, out, scale=3):
    im = Image.open(os.path.join(D,src)).convert("RGB").crop(box)
    im = im.resize((im.width*scale, im.height*scale), Image.NEAREST)
    p = os.path.join(O,out); im.save(p); print(p, im.size)

# 05_top 右侧会议室区（检查短边玻璃是否接到右墙）
crop("ch02_05_top.png",(300,60,480,200),"top_right_rooms.png",3)
# 02_back 天花板灯带
crop("ch02_02_back.png",(100,0,400,80),"back_ceiling.png",3)
# 00_player 天花灯（z=12 那盏）
crop("ch02_00_player.png",(150,20,340,70),"player_lamp.png",4)
# 03_right 会议桌+桌腿
crop("ch02_03_right.png",(0,140,480,270),"right_table.png",2)
