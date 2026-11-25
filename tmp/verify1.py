from PIL import Image
import os
D = r"D:\mygame\tmp\shots\chapter_audit"
M = r"D:\mygame\assets\materials"
def L(p): return (0.2126*p[0]+0.7152*p[1]+0.0722*p[2])/255.0
def load(n): return Image.open(os.path.join(D,n)).convert("RGB")

# ============ 验证 A：发光面 UV 污染（模拟 triplanar 采样） ============
tex = Image.open(os.path.join(M,"WhiteCeiling_MetalEdge.png")).convert("RGB")
def sample(u,v):
    x = int(round((u % 1.0)*199)); y = int(round((v % 1.0)*199))
    return tex.getpixel((min(max(x,0),199), min(max(y,0),199)))
print("== 预测：21 盏灯发光面 (down panel, uv=p*0.5, v 由 z 决定) ==")
tint = (1.0,0.99,0.95)
for z in [-18,-12,-6,0,6,12,18]:
    for x in [-7,0,7]:
        v = z*0.5
        # 发光面沿 z 跨度 0.30m -> v +-0.075
        va, vb = v-0.075, v+0.075
        ca = sample(0.5, va); cb = sample(0.5, vb)
        print(f"  lamp({x:2d},{z:3d})  v={v:6.2f}  z-半(va={va:6.3f}) rgb={ca} luma={L(ca):.3f}   z+半(vb={vb:6.3f}) rgb={cb} luma={L(cb):.3f}")

# ============ 验证 B：Glass 贴图平铺 ============
gt = Image.open(os.path.join(M,"Glass.png")).convert("RGB")
print()
print("== Glass 贴图：左边缘一列深青，其余浅蓝 ==")
print("   (0,0)=",gt.getpixel((0,0)), " (5,0)=",gt.getpixel((5,0)), " (0,100)=",gt.getpixel((0,100)))
# 玻璃长边 5.0m 沿 z，uv=p*0.5 -> 每 2m 一个周期
print("   玻璃长边 5.0m，uv1_scale=0.5 -> z 跨 2.5 个 UV 周期 -> 每 2.0m 一条深青竖线")
for zz in [-11.0,-10.0,-9.0,-8.5,-8.0,-6.0]:
    u = zz*0.5
    px = int(round((u % 1.0)*199))
    print(f"   z={zz:6.1f} u={u:6.2f} 采样列 x={px} 颜色={gt.getpixel((px,100))}")
