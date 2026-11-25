from PIL import Image
p = r"D:\mygame\assets\sprites\weapon_pistol_hud.png"
im = Image.open(p).convert("RGBA")
# 逐列统计不透明像素的 x 范围
xs = [x for x in range(im.width) for y in range(im.height) if im.getpixel((x,y))[3] > 40]
ys = [y for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3] > 40]
print("bbox", min(xs), min(ys), max(xs), max(ys))
