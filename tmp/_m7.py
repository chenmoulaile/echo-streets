import numpy as np
from PIL import Image
b = r"D:\mygame\tmp\shots"
print("frame        darkpx  bbox(x0,x1,y0,y1)   topmost_row_x_span")
for n in ["01_idle.png","02_fire.png","03_reload.png","04_dead.png"]:
    a = np.asarray(Image.open(b+"\\"+n).convert("RGB")).astype(np.int32)
    r,g,bch = a[:,:,0],a[:,:,1],a[:,:,2]
    lum = 0.299*r+0.587*g+0.114*bch
    mx=np.maximum(np.maximum(r,g),bch); mn=np.minimum(np.minimum(r,g),bch)
    sat=np.where(mx>0,(mx-mn)*255.0/np.maximum(mx,1),0)
    m = (lum<70)&(sat<45)
    m[:100,:]=False; m[:,:200]=False
    ys,xs=np.nonzero(m)
    y0=ys.min(); row=np.nonzero(m[y0])[0]
    print("%-12s %5d  (%3d,%3d,%3d,%3d)   y=%d x[%d,%d]" % (n,m.sum(),xs.min(),xs.max(),ys.min(),ys.max(),y0,row.min(),row.max()))
