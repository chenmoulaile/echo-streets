from PIL import Image
import os
M = r"D:\mygame\assets\materials"
def avg(name):
    p = os.path.join(M, name + ".png")
    im = Image.open(p).convert("RGB")
    d = list(im.getdata()); n=len(d)
    r=sum(q[0] for q in d)/n; g=sum(q[1] for q in d)/n; b=sum(q[2] for q in d)/n
    mx = max(max(q) for q in d); mn = min(min(q) for q in d)
    return im.size, (round(r,1),round(g,1),round(b,1)), (mn,mx)
for n in ["WhiteCeiling_MetalEdge","WhiteCeiling","Glass","ComputerScreen_BlueScreen",
          "MetalPlateWall","MetalWall","MetalBox_White","WhiteWall_Dirty","WoodenBox",
          "CeramicFloor_White","YellowWall","WhiteWall","WoodenFloor"]:
    try:
        sz, a, rng = avg(n)
        print(f"{n:28s} {sz} avg={a} luma={(0.2126*a[0]+0.7152*a[1]+0.0722*a[2])/255:.3f} range={rng}")
    except Exception as e:
        print(f"{n:28s} ERR {e}")
