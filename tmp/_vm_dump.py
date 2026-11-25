from PIL import Image
import sys
p = sys.argv[1] if len(sys.argv)>1 else r"D:\mygame\assets\sprites\viewmodel\vm_pistol_idle.png"
im = Image.open(p).convert("RGBA")
w,h = im.size
px = im.load()
print("size", w, h, "bbox", im.getbbox())
for y in range(0, h, 3):
    row = ""
    for x in range(0, w, 2):
        a = px[x,y][3]
        if a < 32: row += "."
        else:
            r,g,b,_ = px[x,y]
            l = (r*299+g*587+b*114)//1000
            row += "#" if l < 60 else ("+" if l < 130 else ("-" if l < 200 else " "))
    print("%3d %s" % (y, row))
