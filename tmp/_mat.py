from PIL import Image
import os
md = r"D:\mygame\assets\materials\\"
for n in ["PoolTiles","WhiteWall","WhiteCeiling","WhiteCeiling_MetalEdge","CeramicFloor_White","CeramicFloor_Gray","MetalPlateWall","MetalWall","WarningLine","WoodenBox","Glass"]:
    im = Image.open(md+n+".png").convert("RGBA")
    w,h = im.size
    px = im.load()
    r=g=b=a=0
    for y in range(h):
        for x in range(w):
            pr,pg,pb,pa = px[x,y]
            r+=pr; g+=pg; b+=pb; a+=pa
    n2=w*h
    print("%-24s %dx%d avg=(%3d,%3d,%3d) alpha=%.0f  hex=#%02X%02X%02X" % (n,w,h,r/n2,g/n2,b/n2,a/n2,int(r/n2),int(g/n2),int(b/n2)))
