from PIL import Image
import os
D=r"D:\mygame\assets\materials"
def L(c): return (0.299*c[0]+0.587*c[1]+0.114*c[2])/255.0
for n in ["CeramicFloor_White","CeramicFloor_Gray","PoolTiles","WhiteWall","WhiteCeiling","MetalPlateWall","MetalWall","WarningLine","RGB_Screen"]:
    p=os.path.join(D,n+".png")
    im=Image.open(p).convert("RGBA"); w,h=im.size
    px=im.load()
    # border = mean of 4 edge lines, inner = mean of a 60x60 center block
    edge=[]
    for x in range(w): edge.append(px[x,0][:3]); edge.append(px[x,h-1][:3])
    for y in range(h): edge.append(px[0,y][:3]); edge.append(px[w-1,y][:3])
    em=tuple(sum(c[i] for c in edge)/len(edge) for i in range(3))
    inner=[px[x,y][:3] for x in range(w//2-30,w//2+30) for y in range(h//2-30,h//2+30)]
    im2=tuple(sum(c[i] for c in inner)/len(inner) for i in range(3))
    print("%-22s size=%dx%d edge=%s L=%.3f  inner=%s L=%.3f  center_texel=%s" % (
        n,w,h,tuple(round(v) for v in em),L(em),tuple(round(v) for v in im2),L(im2),px[w//2,h//2]))
