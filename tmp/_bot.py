import numpy as np
from PIL import Image
d = r"D:\mygame\tmp\shots"
a = np.asarray(Image.open(d+r"\01_idle.png").convert("RGB")).astype(np.int32)
b = np.asarray(Image.open(d+r"\02_fire.png").convert("RGB")).astype(np.int32)
# 底边 4 行、手臂横向范围 x 200..400
for y in (269, 268, 267, 266):
    da = a[y, 200:400]; db = b[y, 200:400]
    diff = np.abs(da-db).sum(axis=1)
    print("y=%d  idle_mean=%s  fire_mean=%s  changed_px=%d" % (
        y, da.mean(axis=0).round(1), db.mean(axis=0).round(1), int((diff>60).sum())))
# 取底行颜色直方图，判断是不是地面色
row = b[269, 200:400]
vals, cnt = np.unique(row.reshape(-1,3), axis=0, return_counts=True)
order = np.argsort(-cnt)[:5]
print("fire bottom-row top colors:", [(tuple(vals[i]), int(cnt[i])) for i in order])
