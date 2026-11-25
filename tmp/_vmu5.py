from PIL import Image
import os
d = r"D:\mygame\assets\sprites\viewmodel"
sel = ["idle","fire1","reload1","reload2","reload3","reload4","draw"]
ims=[]
for n in sel:
    im = Image.open(os.path.join(d,"vm_pistol_%s.png"%n)).convert("RGBA")
    bg = Image.new("RGB", im.size, (58,62,70))
    bg.paste(im,(0,0),im)
    ims.append(bg)
w,h = ims[0].size
sc=2
sheet = Image.new("RGB",(w*sc*len(ims)+6*(len(ims)-1), h*sc),(20,20,24))
for i,im in enumerate(ims):
    sheet.paste(im.resize((w*sc,h*sc), Image.NEAREST),(i*(w*sc+6),0))
p = r"D:\mygame\tmp\shots\_vmu5.png"
sheet.save(p); print(p, sheet.size, "frame", w, h)
