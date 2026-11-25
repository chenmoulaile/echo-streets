## 视角与后坐力解算层。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   player.gd 在补齐后坐力回正、俯仰钳制、后坐叠加后涨到 319 行，超红线。
##   职责切分：player.gd 管"状态与输入路由"，本文件管"俯仰/后坐的数学"。
##   这两块共享 _pitch 与 _recoil_pitch 两个数，但规则独立：
##   视角是硬钳制（pitch_min/max），后坐是软回正（recoil_recovery 度/秒）。
## 设计: 纯函数，pitch 与 recoil 都以"当前值入参、新值出参"的形式传递，
##   调用方负责持有状态，便于单独验证钳制边界。
extends RefCounted

## 后坐力叠加上限（弧度）。±0.3 rad ≈ ±17.2°，超过会让准星彻底失去参考。
const RECOIL_LIMIT := 0.3

## 应用一次视角输入。返回 [新 pitch, 新 recoil]。
## yaw 直接转身体（rotate_y），pitch 只转相机装配，两者不混。
static func apply_look(pitch: float, recoil: float, pitch_delta: float,
		pitch_min_deg: float, pitch_max_deg: float) -> Array:
	var next: float = clampf(pitch + pitch_delta,
		deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	return [next, recoil]

## 后坐力回正。返回 [新 recoil, 是否还在回正]。
## 用 move_toward 而不是乘法衰减：乘法在低帧率下会明显"拖尾"，
## 且永远到不了 0（浮点残值会让相机长期偏一点）。
static func tick_recoil(recoil: float, delta: float, recovery_deg: float) -> Array:
	if is_zero_approx(recoil):
		return [0.0, false]
	var next: float = move_toward(recoil, 0.0, deg_to_rad(recovery_deg) * delta)
	return [next, true]

## 开火时叠加后坐（只抬镜头，不改射线方向 —— 保证准星诚实）。
static func add_recoil(recoil: float, recoil_deg: float) -> float:
	return clampf(recoil + deg_to_rad(recoil_deg), -RECOIL_LIMIT, RECOIL_LIMIT)
