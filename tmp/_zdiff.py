import numpy as np, os, sys
sys.path.insert(0, r"D:\mygame\tmp")
from PIL import Image
import importlib.util
spec = importlib.util.spec_from_file_location("zf", r"D:\mygame\tmp\ZombieFrames2.py")
zf = importlib.util.module_from_spec(spec); spec.loader.exec_module(zf)

src = zf.load(os.path.join(zf.SPRITE_DIR, "zombie_fodder.png"))
for idx in (1,2,4,5):
    new = zf.walk_frame(src, idx, 6)
    old = np.asarray(Image.open(os.path.join(zf.FRAME_DIR, "zombie_fodder_walk_%d.png" % idx)).convert("RGBA"))
    d = (np.abs(old.astype(np.int16)-new.astype(np.int16))>0).any(axis=2)
    ys,xs = np.nonzero(d)
    print("walk_%d  diff=%d  x[%d,%d] y[%d,%d]" % (idx, d.sum(), xs.min(), xs.max(), ys.min(), ys.max()))
    for k in range(min(6, len(ys))):
        y,x = ys[k], xs[k]
        print("   (%3d,%3d) old=%s new=%s" % (x,y,tuple(old[y,x]),tuple(new[y,x])))
