from PIL import Image
d = r"D:\mygame\tmp\shots"
box = (190, 200, 330, 270)   # 手臂与前臂出画区域
ims = [Image.open(d+"\\%s.png" % n).convert("RGB").crop(box) for n in ("01_idle","02_fire","03_reload")]
w,h = ims[0].size
sheet = Image.new("RGB",(w*3*3+16, h*3),(20,20,20))
for i,im in enumerate(ims):
    sheet.paste(im.resize((w*3,h*3), Image.NEAREST), (i*(w*3+8),0))
sheet.save(d+r"\_botcmp.png")
print("saved", sheet.size)
