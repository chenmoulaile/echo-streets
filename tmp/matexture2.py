from PIL import Image
import os
M = r"D:\mygame\assets\materials"
for n in ["YellowWall","WhiteWall","WhiteWall_Dirty","MetalBox_White","CeramicFloor_White"]:
    im = Image.open(os.path.join(M,n+".png")).convert("RGB")
    w,h=im.size
    print(f"== {n} {w}x{h} ==")
    for j in range(0,8):
        row=[]
        for i in range(0,8):
            p=im.getpixel((int(i*w/8),int(j*h/8)))
            row.append(f"{p[0]:3d},{p[1]:3d},{p[2]:3d}")
        print("   "+" | ".join(row))
    print()
