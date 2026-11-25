from PIL import Image
import os
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-04_weapon-_mxload"
for n in ["Weapon_Icon_10000.png","Weapon_Icon_10002.png","Weapon_Icon_13000.png","Weapon_Icon_16000.png"]:
    p = os.path.join(d,n)
    im = Image.open(p)
    print(n, im.size, im.mode)
