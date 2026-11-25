from PIL import Image
b = r"D:\mygame\tmp\shots"
box = (200, 95, 400, 270)   # viewmodel 区域
tiles = []
for n in ["01_idle.png","02_fire.png","03_reload.png","04_dead.png"]:
    im = Image.open(b+"\\"+n).convert("RGB").crop(box)
    tiles.append(im.resize((im.width*2, im.height*2), Image.NEAREST))
W = tiles[0].width; H = tiles[0].height
sheet = Image.new("RGB", (W*2, H*2), (0,0,0))
for i,t in enumerate(tiles):
    sheet.paste(t, ((i%2)*W, (i//2)*H))
sheet.save(b+"\\_vm4.png")
print(sheet.size)
