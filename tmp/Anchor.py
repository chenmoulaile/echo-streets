"""量 BOOM 参考帧的构图锚点：枪口、枪身质心、手部质心，全部归一化到画面。

为什么要量而不是目测：参考帧 1100x452 与游戏 480x270 宽高比不同，
「看起来在中间」和「muzzle 落在屏幕 53%」是两件事，只有坐标能比。
"""
import numpy as np
from PIL import Image


def anchors(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    a = np.asarray(im).astype(np.int32)
    op = a[:, :, 3] > 40
    if not op.any():
        return None
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)

    skin = op & (r - b > 28) & (r - g > 12) & (lum > 90) & (lum < 235) & (sat < 110)
    shirt = op & (lum > 200) & (sat < 45)
    navy = op & (lum < 100) & (b > r + 18)
    gun = op & ~skin & ~shirt & ~navy

    ys, xs = np.nonzero(op)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max(), ys.max()
    top = by0
    muzzle_x = float(xs[ys <= top + 4].mean())
    gy, gx = np.nonzero(gun)
    gun_cx = float(gx.mean()) if gx.size else float("nan")
    gun_cy = float(gy.mean()) if gy.size else float("nan")
    hy, hx = np.nonzero(skin | navy)
    hand_cx = float(hx.mean()) if hx.size else float("nan")
    hand_cy = float(hy.mean()) if hy.size else float("nan")

    print(f"{path.split(chr(92))[-1]}")
    print(f"  画幅 {w}x{h}  bbox {bx0},{by0} - {bx1},{by1}  ({bx1-bx0}x{by1-by0})")
    print(f"  枪口   x={muzzle_x:7.1f} ({muzzle_x/w*100:5.1f}%)  y={top} ({top/h*100:5.1f}%)")
    print(f"  枪身质心 x={gun_cx:7.1f} ({gun_cx/w*100:5.1f}%)  y={gun_cy:6.1f} ({gun_cy/h*100:5.1f}%)")
    print(f"  手部质心 x={hand_cx:7.1f} ({hand_cx/w*100:5.1f}%)  y={hand_cy:6.1f} ({hand_cy/h*100:5.1f}%)")
    print(f"  枪口相对枪身质心 dx={muzzle_x-gun_cx:+.1f} ({(muzzle_x-gun_cx)/w*100:+.1f}% 屏宽)")
    print(f"  像素占比 不透明 {op.sum()/op.size*100:5.2f}%  枪身 {gun.sum()/op.size*100:5.2f}%")
    return dict(muzzle_x=muzzle_x, top=top, w=w, h=h,
                bx0=bx0, by0=by0, bx1=bx1, by1=by1,
                gun_cx=gun_cx, gun_cy=gun_cy)


if __name__ == "__main__":
    for p in [
        r"D:\mygame\tmp\fp_png\Handgun__HandgunIdle.png",
        r"D:\mygame\tmp\fp_png\Shotgun__ShotgunIdle.png",
    ]:
        anchors(p)
