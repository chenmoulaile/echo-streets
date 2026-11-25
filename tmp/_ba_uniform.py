# -*- coding: utf-8 -*-
from PIL import Image
import os, collections
d = r"D:\Bluearchive\repo\resources\ui\local\uis-01_common-01_character-_mxload"
picks = ["NPC_Portrait_Justice_normal1.png","NPC_Portrait_Fuuki_Normal1.png","NPC_Portrait_Helmetdan_Black1.png"]
for n in picks:
    p = os.path.join(d,n)
    im = Image.open(p).convert("RGBA")
    px = [q[:3] for q in im.getdata() if q[3] > 40]
    t = Image.new("RGB",(len(px),1)); t.putdata(px)
    q = t.quantize(colors=10, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pl = q.getpalette()[:30]; cnt = collections.Counter(q.getdata())
    print("%-36s %s" % (n, im.size))
    for idx,c in cnt.most_common(10):
        r,g,b = pl[idx*3:idx*3+3]
        L=(r*299+g*587+b*114)//1000; sat=max(r,g,b)-min(r,g,b)
        kind = "白衬衫" if L>200 and sat<40 else ("深色制服" if L<80 else ("肤色" if r-b>25 and r>140 else "中间调"))
        print("    %5.1f%%  rgb(%3d,%3d,%3d)  L=%3d sat=%3d  %s" % (c/len(px)*100, r,g,b,L,sat,kind))
