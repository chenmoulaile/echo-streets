from PIL import Image
b = r"D:\mygame\tmp\shots"
for n,box in [("01_idle.png",(200,90,300,180)),("02_fire.png",(200,90,300,180))]:
    im = Image.open(b+"\\"+n).convert("RGB").crop(box)
    im.resize((im.width*6, im.height*6), Image.NEAREST).save(b+"\\_mz_"+n)
print("ok")
