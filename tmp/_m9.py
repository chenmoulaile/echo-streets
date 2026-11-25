from PIL import Image
md = r"D:\mygame\assets\materials\\"
for n in ["CeramicFloor_Gray","PoolTiles","WhiteCeiling","WhiteWall","MetalPlateWall","MetalWall"]:
    im = Image.open(md+n+".png").convert("RGB")
    w,h=im.size; px=im.load()
    # 检查边缘一圈是否比内部暗（平铺接缝）
    def avg(pts):
        s=0
        for (x,y) in pts:
            r,g,b=px[x,y]; s+=(0.299*r+0.587*g+0.114*b)/255
        return s/len(pts)
    edge=[(x,0) for x in range(w)]+[(x,h-1) for x in range(w)]+[(0,y) for y in range(h)]+[(w-1,y) for y in range(h)]
    inner=[(x,y) for y in range(20,h-20) for x in range(20,w-20)]
    print("%-20s edge L=%.3f  inner L=%.3f" % (n, avg(edge), avg(inner)))
