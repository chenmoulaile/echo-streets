from PIL import Image
import os, re
d = r"D:\mygame\assets\sprites\zombie_frames"
def frames(prefix, state):
    fs = [f for f in os.listdir(d) if f.startswith(prefix+"_"+state+"_") and f.endswith(".png")]
    fs.sort(key=lambda f: int(re.search(r"_(\d+)\.png$", f).group(1)))
    return [Image.open(os.path.join(d,f)).convert("RGBA") for f in fs]

rows = [(s, frames("zombie_fodder", s)) for s in ("idle","walk","run","attack","grab")]
W,H = 128,96
cols = max(len(r[1]) for r in rows)
sheet = Image.new("RGBA",(cols*W, len(rows)*H),(30,32,36,255))
for ri,(s,ims) in enumerate(rows):
    for ci,im in enumerate(ims):
        sheet.alpha_composite(im,(ci*W, ri*H))
sheet = sheet.resize((sheet.width*2, sheet.height*2), Image.NEAREST)
sheet.save(r"D:\mygame\tmp\shots\_zrun.png")
print("sheet", sheet.size, [(s,len(f)) for s,f in rows])
