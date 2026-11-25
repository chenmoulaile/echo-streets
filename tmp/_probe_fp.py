from PIL import Image
import os
d = r"D:\mygame\tmp\fp_png"
if not os.path.isdir(d):
    print("NO DIR", d); raise SystemExit
names = sorted(os.listdir(d))
print("count", len(names))
for n in names:
    if "Handgun" in n and ("Idle" in n or "Fire" in n):
        print(n)
