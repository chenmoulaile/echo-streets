from PIL import Image
import glob, os
d = r"D:\mygame\assets\sprites\viewmodel"
order = ["idle","dry","fire1","fire2","fire3","reload1","reload2","reload3","reload4","draw"]
ims = [Image.open(os.path.join(d,"vm_pistol_%s.png"%n)).convert("RGBA") for n in order]
w,h = ims[0].size
sc = 2
tw,th = w*sc, h*sc
cols = 5
sheet = Image.new("RGB",(tw*cols + (cols-1)*4, th*2 + 4),(30,30,34))
for i,im in enumerate(ims):
    bg = Image.new("RGB",(w,h),(46,52,60))
    bg.paste(im, (0,0), im)
    sheet.paste(bg.resize((tw,th), Image.NEAREST), ((i%cols)*(tw+4), (i//cols)*(th+4)))
p = r"D:\mygame\tmp\shots\_vmu.png"
sheet.save(p); print(p, sheet.size)
