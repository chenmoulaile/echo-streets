import numpy as np
from PIL import Image

base = r"D:\mygame\tmp\shots"
a = np.asarray(Image.open(base+r"\01_idle.png").convert("RGB")).astype(np.int32)
b = np.asarray(Image.open(base+r"\02_fire.png").convert("RGB")).astype(np.int32)
d = np.abs(a-b).sum(axis=2)
# 只看 viewmodel 可能区域 x>=180 y>=90，且强差异
m = (d > 60)
m[:90,:] = False
m[:, :180] = False
ys,xs = np.nonzero(m)
print("strong-diff px=%d  bbox x[%d,%d] y[%d,%d] centroid=(%.1f,%.1f)"
      % (len(xs), xs.min(), xs.max(), ys.min(), ys.max(), xs.mean(), ys.mean()))
# 分区统计：枪口应在 (232,120) 附近
for label,(x0,x1,y0,y1) in [("muzzle_zone",(210,260,95,135)),
                            ("body_zone",(230,380,130,270)),
                            ("left_zone",(180,215,90,270))]:
    sub = m[y0:y1, x0:x1]
    print("  %-12s diff_px=%4d" % (label, sub.sum()))
# 火光颜色：在 muzzle_zone 内找最亮像素
z = b[95:135, 210:260]
lum = 0.299*z[:,:,0]+0.587*z[:,:,1]+0.114*z[:,:,2]
iy,ix = np.unravel_index(np.argmax(lum), lum.shape)
print("  muzzle_zone brightest rgb=%s at (%d,%d)" % (tuple(z[iy,ix]), ix+210, iy+95))
