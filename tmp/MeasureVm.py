"""量底板的枪口位置与关键几何，用于合成动画帧。"""
import numpy as np
from PIL import Image

for name in ("pistol", "shotgun"):
    im = Image.open(r"D:\mygame\tmp\pxout\vm_%s_idle.png" % name).convert("RGBA")
    a = np.asarray(im)
    alpha = a[:, :, 3]
    h, w = alpha.shape
    print("===", name, w, h)
    ys, xs = np.nonzero(alpha > 40)
    print("bbox", (xs.min(), ys.min(), xs.max(), ys.max()))

    # 枪口 = 上半部分最左的非透明像素
    top_half = alpha[: h // 2, :]
    ys2, xs2 = np.nonzero(top_half > 40)
    if len(xs2):
        i = xs2.argmin()
        print("左上尖端 (枪口候选)", (int(xs2[i]), int(ys2[i])))

    # 逐行最左边界，找枪管尖端
    print("每 8 行最左 x:")
    for y in range(0, h, 8):
        row = np.nonzero(alpha[y] > 40)[0]
        if len(row):
            print("   y=%3d  x=%3d..%3d" % (y, row.min(), row.max()))
