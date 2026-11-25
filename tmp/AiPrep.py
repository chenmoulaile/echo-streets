"""AI 生图底板预处理 v5：洋红抠图 + 固定矩形水印擦除 + 前景包围盒报告。

水印「AI生成」在每张生成图里都固定在右下角（约 1920 图的 x 1500~1900、y 1630~1890）。
不要用颜色阈值自动找 —— 白衬衫袖口同样近白低饱和，会被一起框进来。
这里直接擦固定矩形，按行取框外左右 70px 的中值填平，保住袖子横向明暗分层。

洋红背景判定用**色相**而不是亮度：洋红被水印提亮后是 (247,127,190)，
仍然满足 (r-g)>80 且 (b-g)>20；皮肤 (241,191,158) 是 (r-g)=50 不满足，
白衬衫 (240,240,240) 是 0 不满足。这样水印落在洋红上的部分会被当作背景去掉。

注意 numpy 里 int16 算 255*587 会溢出成负数，亮度必须用 int32。

用法: py -3 tmp/AiPrep.py <src> <dst>
"""
import sys
import numpy as np
from PIL import Image

WM_RECT = (1500, 1630, 1900, 1890)  # x0, y0, x1, y1（1920x1920 基准，按比例缩放）

src, dst = sys.argv[1], sys.argv[2]

im = Image.open(src).convert("RGB")
w, h = im.size
a = np.asarray(im).astype(np.int32)

r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
bg = ((r - g) > 80) & ((b - g) > 20)

# 固定矩形水印擦除（按图尺寸缩放）
sx, sy = w / 1920.0, h / 1920.0
x0, y0 = int(WM_RECT[0] * sx), int(WM_RECT[1] * sy)
x1, y1 = int(WM_RECT[2] * sx), int(WM_RECT[3] * sy)
print("wm rect", (x0, y0, x1, y1))

for y in range(y0, y1 + 1):
    left = a[y, max(0, x0 - 70):x0]
    right = a[y, x1 + 1:min(w, x1 + 71)]
    ring = np.vstack([left, right])
    ring = ring[~(((ring[:, 0] - ring[:, 1]) > 80) & ((ring[:, 2] - ring[:, 1]) > 20))]
    if len(ring) == 0:
        continue
    fill = np.median(ring, axis=0).astype(np.int32)
    a[y, x0:x1 + 1] = fill

alpha = np.where(bg, 0, 255).astype(np.uint8)
rgba = np.dstack([np.clip(a, 0, 255).astype(np.uint8), alpha])
Image.fromarray(rgba, "RGBA").save(dst)

ys2, xs2 = np.nonzero(~bg)
print("fg bbox", (int(xs2.min()), int(ys2.min()), int(xs2.max()), int(ys2.max())),
      "size", (int(xs2.max() - xs2.min() + 1), int(ys2.max() - ys2.min() + 1)))
print("saved", dst)
