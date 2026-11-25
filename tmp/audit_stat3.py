from PIL import Image
im=Image.open(r"D:\mygame\tmp\shots\chapter\ch02_05_top.png").convert("RGB")
from collections import Counter
c=Counter(im.getdata())
for rgb,n in c.most_common(8):
    print(rgb, n, round(n/(480*270)*100,2))
