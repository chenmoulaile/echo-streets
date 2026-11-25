from PIL import Image
import os
src = r"D:\mygame\tmp\fp_png"
names = ["Handgun__HandgunIdle.png","Handgun__Handgun_Reload1.png","Handgun__Handgun_Reload2.png",
         "Handgun__Handgun_Reload3.png","Handgun__Handgun_Reload4.png",
         "Handgun__HandgunFire1.png","Handgun__HandgunFire2.png","Handgun__HandgunFire3.png"]
box = (200, 40, 1100, 452)   # 全屏 overlay，裁掉左半空区
ims = []
for n in names:
    im = Image.open(os.path.join(src,n)).convert("RGB")
    ims.append(im.crop(box))
w,h = ims[0].size
sc = 0.42
tw, th = int(w*sc), int(h*sc)
cols, rows = 4, 2
sheet = Image.new("RGB",(tw*cols+ (cols-1)*6, th*rows+6),(24,24,28))
for i,im in enumerate(ims):
    sheet.paste(im.resize((tw,th), Image.LANCZOS), ((i%cols)*(tw+6), (i//cols)*(th+6)))
p = r"D:\mygame\tmp\shots\_refreload.png"
sheet.save(p)
print(p, sheet.size)
for n,im in zip(names, ims):
    a = im.convert("L").point(lambda v: 255 if v>26 else 0)
    bb = a.getbbox()
    print("%-34s bbox=%s" % (n, bb))
