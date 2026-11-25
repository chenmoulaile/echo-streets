from PIL import Image
d = r"D:\mygame\tmp\shots\chapter\\"
im = Image.open(d+"ch03_05_top.png").convert("RGB")
px=im.load(); w,h=im.size
print("== ch03_05 底部黑区 ==")
for y in [200,210,220,230,240,250,260,269]:
    row=[]
    for x in [0,60,120,180,240,300,360,420,479]:
        r,g,b=px[x,y]
        row.append("%.2f"%((0.299*r+0.587*g+0.114*b)/255))
    print(" y=%3d "%y + " ".join(row))
print("== 顶部黑角 ==")
for y in [0,5,10,15,20,25]:
    row=[]
    for x in [0,40,80,240,400,440,479]:
        r,g,b=px[x,y]
        row.append("%.2f"%((0.299*r+0.587*g+0.114*b)/255))
    print(" y=%3d "%y + " ".join(row))
