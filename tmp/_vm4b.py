from PIL import Image
import os
d = r"D:\mygame\tmp\shots"
sel = ["01_idle","02_fire","03_reload","04_dead"]
ims=[Image.open(os.path.join(d,"%s.png"%n)).convert("RGB") for n in sel]
w,h = ims[0].size
sc=2
sheet = Image.new("RGB",(w*sc*2+6, h*sc*2+6),(16,16,20))
for i,im in enumerate(ims):
    sheet.paste(im.resize((w*sc,h*sc), Image.NEAREST),((i%2)*(w*sc+6),(i//2)*(h*sc+6)))
p = os.path.join(d,"_vm4b.png"); sheet.save(p); print(p, sheet.size)
