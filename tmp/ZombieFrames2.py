"""丧尸纸片人帧合成器（Python 复刻 + 扩展）。

为什么是 Python 而不是继续用 tmp/ZombieAtlas.cs:
  ZombieAtlas.cs 是 static class，没有 Main，tmp/ 下也没有 csproj —— 复跑它得先
  造一个 .NET 工程。而它用的 System.Drawing 在非 Windows 上还要额外兼容包。
  Python + Pillow 复刻同样的算法只要 200 行，且能顺手做「逐像素比对原 20 帧」的
  回归校验：只要 idle/walk/attack/hurt/death 与原帧逐字节相同，就证明移植没走样。

为什么只新增 run / grab 两态、不重生成旧 5 态:
  旧 5 态已经过 12 轮目视验证（步态两相、髋部枢轴剪切、死亡画布加宽）。
  重生成只是重复劳动，风险却一样 —— 这里用 verify 模式证明新旧一致即可。

用法:
  py -3 tmp\\ZombieFrames2.py verify            # 旧 5 态与原帧逐像素比对
  py -3 tmp\\ZombieFrames2.py emit              # 只写 run / grab 两态
  py -3 tmp\\ZombieFrames2.py emit --all        # 5 态 + 2 态全写（重建时用）
"""
from __future__ import annotations

import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

SPRITE_DIR = r"D:\mygame\assets\sprites"
FRAME_DIR = os.path.join(SPRITE_DIR, "zombie_frames")
VARIANTS = ["zombie_fodder", "zombie_charger", "zombie_bomber", "zombie_screamer"]

SRC = 96          # 源图边长
CW = 128          # 单格宽（死亡帧横躺需要 128）
CH = 96           # 单格高
PAD = (CW - SRC) // 2   # 源图在格内水平居中偏移 = 16

# 部位切分：坐标基于 96x96 源图（alpha 列剖面实测）。含 1px 重叠，避免重排后出现缝。
LEG_L = (35, 56, 49, 95)
LEG_R = (48, 56, 64, 95)
TORSO = (24, 25, 72, 58)
ARM_L = (10, 26, 36, 50)
ARM_R = (60, 26, 86, 50)
HEAD = (26, 0, 70, 28)

DEATH_ANGLES = [0.0, 0.40, 0.85, 1.25, 1.50]


def load(path: str) -> np.ndarray:
    a = np.asarray(Image.open(path).convert("RGBA"))
    if a.shape[0] != SRC or a.shape[1] != SRC:
        raise SystemExit("SKIP %s (canvas %dx%d, expected 96x96)" % (path, a.shape[1], a.shape[0]))
    return a


def f32(x: float) -> float:
    """按 float32 舍入。

    C# 版把所有中间量声明成 float（单精度），再交给 Math.Round(double)。Python 全程
    双精度，在 0.5 边界上会算出不同的整数 —— 实测 walk 帧因此差 6~25 个像素。
    要逐像素复现旧帧，就必须把这些中间量也压到单精度。
    """
    return float(np.float32(x))


def blit(cell: np.ndarray, src: np.ndarray, part: tuple, dx: int, dy: int, squash: float = 1.0) -> None:
    """把 src 的一个部位按 (dx,dy) 贴到 cell 上；squash 把部位按相对行距压扁。"""
    x0, y0, x1, y1 = part
    for sy in range(y0, y1 + 1):
        rel = sy - y0
        ty = int(y0 + dy + round(f32(f32(rel) * f32(squash))))
        if ty < 0 or ty >= CH:
            continue
        for sx in range(x0, x1 + 1):
            tx = sx + dx + PAD
            if tx < 0 or tx >= CW:
                continue
            c = src[sy, sx]
            if c[3] < 40:
                continue
            cell[ty, tx] = c


def shear(cell: np.ndarray, src: np.ndarray, part: tuple, swing: float, lift: int, compress: float = 1.0) -> None:
    """绕顶端枢轴摆动：位移随离枢轴距离线性增长，髋部不动、末端摆幅最大。

    整体平移会在髋部撕出缺口，剪切才是正确的枢轴旋转近似。
    """
    x0, y0, x1, y1 = part
    hgt = y1 - y0 + 1
    if hgt <= 0:
        return
    for sy in range(y0, y1 + 1):
        rel = sy - y0
        t = f32(f32(rel) / f32(hgt))
        ty = int(y0 - lift + round(f32(f32(rel) * f32(compress))))
        if ty < 0 or ty >= CH:
            continue
        dx = int(round(f32(f32(swing) * t)))
        for sx in range(x0, x1 + 1):
            tx = sx + dx + PAD
            if tx < 0 or tx >= CW:
                continue
            c = src[sy, sx]
            if c[3] < 40:
                continue
            cell[ty, tx] = c


def rotate_cell(src: np.ndarray, angle: float) -> np.ndarray:
    """死亡：绕脚底 (64,96) 旋转整帧。格内坐标已是 128 宽，需减 PAD 映射回源图。"""
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    pivot_x, pivot_y = 64.0, 96.0
    cos, sin = math.cos(angle), math.sin(angle)
    for y in range(CH):
        for x in range(CW):
            rx, ry = x - pivot_x, y - pivot_y
            sx = pivot_x + rx * cos + ry * sin - PAD
            sy = pivot_y - rx * sin + ry * cos
            ix, iy = int(round(sx)), int(round(sy))
            if ix < 0 or ix >= SRC or iy < 0 or iy >= SRC:
                continue
            c = src[iy, ix]
            if c[3] < 40:
                continue
            cell[y, x] = c
    return cell


# ── 各状态单帧生成 ─────────────────────────────────────────────

def idle_frame(src: np.ndarray, phase: float) -> np.ndarray:
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    bob = int(round(1.0 * math.sin(phase * math.pi * 2.0)))
    blit(cell, src, LEG_L, 0, 0)
    blit(cell, src, LEG_R, 0, 0)
    blit(cell, src, TORSO, 0, bob)
    blit(cell, src, ARM_L, 0, bob + 1)
    blit(cell, src, ARM_R, 0, bob + 1)
    blit(cell, src, HEAD, 0, bob * 2)
    return cell


def gait(cell: np.ndarray, src: np.ndarray, cycle: float,
         swing_px: float, lift_px: int, bob_px: float, arm_px: float,
         compress_k: float, torso_dy: int = 0) -> None:
    """两相步态：摆动腿离地屈膝前摆，支撑腿伸直后拖。

    纯正弦在对称相位上取值相等会让相邻帧长得一模一样，必须用两相区分去程与回程。

    精度对齐 C# 原文（这是逐像素复现的前提）：
      bob / lift 全程 double（C# 里是 `Math.Round(double)`），只有 swing / compress
      在 C# 里声明成 float，所以只有这两个要在 double 算完后压成单精度。
      把 bob/lift 也压成 float32 会改掉 round 的边界取值，帧会整体错位 1px。
    """
    bob = int(round(-bob_px * math.cos(4.0 * math.pi * cycle)))
    for leg in (0, 1):
        phase = (cycle + (0.0 if leg == 0 else 0.5)) % 1.0
        part = LEG_L if leg == 0 else LEG_R
        if phase < 0.5:
            u = phase / 0.5
            swing = f32(-swing_px + 2.0 * swing_px * u)
            lift = int(round(lift_px * math.sin(u * math.pi)))
            compress = f32(1.0 - lift * compress_k)
        else:
            u = (phase - 0.5) / 0.5
            swing = f32(swing_px - 2.0 * swing_px * u)
            lift = 0
            compress = 1.0
        shear(cell, src, part, swing, lift, compress)
    arm_phase = (cycle + 0.5) % 1.0
    arm_swing = f32(-arm_px + 2.0 * arm_px * arm_phase)
    blit(cell, src, TORSO, 0, bob + torso_dy)
    shear(cell, src, ARM_L, arm_swing, 0, 1.0)
    shear(cell, src, ARM_R, f32(-arm_swing), 0, 1.0)
    blit(cell, src, HEAD, 0, bob * 2 + torso_dy)


def walk_frame(src: np.ndarray, index: int, frames: int) -> np.ndarray:
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    gait(cell, src, index / frames, swing_px=6.0, lift_px=5, bob_px=2.0, arm_px=3.0, compress_k=0.016)
    return cell


def run_frame(src: np.ndarray, index: int, frames: int) -> np.ndarray:
    """跑动：同一套两相步态，但摆幅更大、抬腿更高、躯干前倾、手臂摆动更猛。

    不另写一套步态逻辑 —— 跑步与走路是同一件事的两个幅度档，
    参数化之后两者共用 gait()，改一处两边同时生效。

    幅度是按「正面纸片人能读出来」倒推的：walk 的 ±6px 摆幅在 128px 画布上只动
    脚踝，跑动必须让脚端摆到 ±14px（≈ 半个腿长）才能一眼看出在跑而不是在走。
    """
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    gait(cell, src, index / frames, swing_px=14.0, lift_px=9, bob_px=3.5, arm_px=9.0,
         compress_k=0.020, torso_dy=2)
    return cell


def attack_frame(src: np.ndarray, index: int) -> np.ndarray:
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    reach = 6 if index == 1 else (3 if index == 2 else 0)
    lean = 3 if index == 1 else 0
    blit(cell, src, LEG_L, 0, 0)
    blit(cell, src, LEG_R, 0, 0)
    blit(cell, src, TORSO, 0, lean)
    blit(cell, src, ARM_L, -reach, 2 + lean)
    blit(cell, src, ARM_R, reach, 2 + lean)
    blit(cell, src, HEAD, 0, lean * 2 + 1)
    return cell


# (out, inward, lean, head_dy, arm_dy)：out = 双臂向外张开量，inward = 双手向内合拢量。
# grab 与 attack 的区别就在 inward —— attack 是「张爪抓空」，grab 是「双手合拢钳住」。
# inward 必须大于 out，双手才会越过躯干中线在胸前交叠：正面视角下「抓住」唯一读得出的
# 形态就是两只手合到身前，纯横向张开只会读成又一次挥空。
GRAB_POSES = [
    (2, 0, 0, 1, -2),     # 抬臂起手
    (4, 6, 2, 2, -3),     # 前扑，双手开始收
    (0, 16, 3, 2, -3),    # 合拢钳住（双手在胸前交叠）
    (0, 11, 1, 1, -1),    # 往回拽
]


def grab_frame(src: np.ndarray, index: int) -> np.ndarray:
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    out, inward, lean, head_dy, arm_dy = GRAB_POSES[index]
    blit(cell, src, LEG_L, 0, 0)
    blit(cell, src, LEG_R, 0, 0)
    blit(cell, src, TORSO, 0, lean)
    blit(cell, src, ARM_L, -out + inward, 2 + lean + arm_dy)
    blit(cell, src, ARM_R, out - inward, 2 + lean + arm_dy)
    blit(cell, src, HEAD, 0, head_dy + lean)
    return cell


def hurt_frame(src: np.ndarray, index: int) -> np.ndarray:
    cell = np.zeros((CH, CW, 4), dtype=np.uint8)
    back = -4 if index == 0 else -1
    blit(cell, src, LEG_L, 0, 0)
    blit(cell, src, LEG_R, 0, 0)
    blit(cell, src, TORSO, back, 1)
    blit(cell, src, ARM_L, back - 3, 0)
    blit(cell, src, ARM_R, back + 3, 0)
    blit(cell, src, HEAD, back, 3)
    return cell


# ── 帧表 ───────────────────────────────────────────────────────
# 每项 (state, 帧数, 生成器)。旧 5 态的顺序与数量必须与 zombie_sprite.gd 的 ANIMS 一致。

def legacy_frames(src: np.ndarray) -> list:
    out = []
    for i in range(4):
        out.append(("idle", i, idle_frame(src, i / 4.0)))
    for i in range(6):
        out.append(("walk", i, walk_frame(src, i, 6)))
    for i in range(3):
        out.append(("attack", i, attack_frame(src, i)))
    for i in range(2):
        out.append(("hurt", i, hurt_frame(src, i)))
    for i, ang in enumerate(DEATH_ANGLES):
        out.append(("death", i, rotate_cell(src, ang)))
    return out


def new_frames(src: np.ndarray) -> list:
    out = []
    for i in range(6):
        out.append(("run", i, run_frame(src, i, 6)))
    for i in range(len(GRAB_POSES)):
        out.append(("grab", i, grab_frame(src, i)))
    return out


def save(path: str, cell: np.ndarray) -> None:
    Image.fromarray(cell, mode="RGBA").save(path, optimize=True)


def cmd_verify() -> int:
    """把旧 5 态重算一遍，与原帧逐像素比对。全 0 差异才说明移植没走样。"""
    bad = 0
    for variant in VARIANTS:
        src = load(os.path.join(SPRITE_DIR, variant + ".png"))
        for state, i, cell in legacy_frames(src):
            path = os.path.join(FRAME_DIR, "%s_%s_%d.png" % (variant, state, i))
            if not os.path.exists(path):
                print("MISSING %s" % path)
                bad += 1
                continue
            old = np.asarray(Image.open(path).convert("RGBA"))
            if old.shape != cell.shape:
                print("SHAPE  %s old=%s new=%s" % (path, old.shape, cell.shape))
                bad += 1
                continue
            diff = int((np.abs(old.astype(np.int16) - cell.astype(np.int16)) > 0).any(axis=2).sum())
            if diff:
                print("DIFF   %s  %d px" % (os.path.basename(path), diff))
                bad += 1
    if bad == 0:
        print("[verify] 80/80 帧逐像素一致")
        return 0
    print("[verify] %d 帧不一致" % bad)
    return 1


def cmd_emit(all_states: bool) -> int:
    for variant in VARIANTS:
        src = load(os.path.join(SPRITE_DIR, variant + ".png"))
        frames = new_frames(src)
        if all_states:
            frames = legacy_frames(src) + frames
        total = 0
        for state, i, cell in frames:
            path = os.path.join(FRAME_DIR, "%s_%s_%d.png" % (variant, state, i))
            save(path, cell)
            total += 1
        counts = {}
        for state, _i, _c in frames:
            counts[state] = counts.get(state, 0) + 1
        print("[emit] %-18s %2d 帧  %s" % (variant, total, counts))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["verify", "emit"])
    ap.add_argument("--all", action="store_true", help="emit 时连同旧 5 态一起重写")
    args = ap.parse_args()
    if args.mode == "verify":
        return cmd_verify()
    return cmd_emit(args.all)


if __name__ == "__main__":
    sys.exit(main())
