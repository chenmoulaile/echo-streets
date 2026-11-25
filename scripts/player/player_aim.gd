## 开镜（ADS）策略层：FOV 过渡 / 灵敏度缩放 / 散布与后坐乘数。
## 挂载节点类型: 无（extends RefCounted，由 Player 持有实例）
## 拆出理由（PDF 硬红线：单文件 ≤ 300 行）：
##   player.gd 已达 294 行，接入 aim / bash / 灵敏度三项必然越线。
##   开镜的全部状态都是"摄像机 + 数值缩放"，与移动/血量/武器槽零耦合，
##   单独成层后 player.gd 只需要转发输入，不持有任何 tween 或 FOV 逻辑。
## 设计要点:
##   1. **ADS 不改枪口位置** —— 射线起点与朝向永远取摄像机中心（准星即命中点），
##      WeaponMount 在哪都无所谓。所以这里只管 FOV 与两个乘数，
##      枪口表现交给 HUD 的 viewmodel 位移（Viewmodel.ADS_SHIFT）。
##   2. 后坐乘数只在 Weapon 侧乘一次（Weapon._ads_recoil），
##      Player._on_weapon_fired 不再二次衰减，否则衰减平方。
##   3. _apply_fov 必须 kill 旧 tween：连续快速按开镜会叠多条 tween 抢同一个
##      Camera3D.fov，表现为"抖动 + 卡在中间值"。
##   4. 灵敏度只在 Player 侧对鼠标增量乘系数，不写 InputMap ——
##      输入映射是按键语义，鼠标速率不是它的职责域。
extends RefCounted

## 无开镜基准 FOV（与 scenes/player.tscn 的 Camera3D.fov 一致）
const BASE_FOV := 75.0
## 开镜 FOV。75→55 视觉放大率约 1.36x，够看清 90m 外的头，又不至于像狙击镜。
const ADS_FOV := 55.0
## 开镜时鼠标灵敏度乘数。FOV 收窄会放大角速度，不降灵敏度会"过冲"。
const ADS_SENS := 0.55
## 开镜时散布乘数（霰弹枪收束明显，手枪几乎无感）
const ADS_SPREAD := 0.35
## 开镜时后坐乘数
const ADS_RECOIL := 0.70
## FOV 过渡时长。低于 0.08 读作"闪"而不是"抬枪"，高于 0.2 手感发黏。
const ADS_TIME := 0.12

var aiming: bool = false
## 0.0~1.0 过渡进度。HUD 用它做准星淡出与 viewmodel 位移的同步混合。
var blend: float = 0.0

var _camera: Camera3D
var _tween: Tween

## 绑定摄像机并把 FOV 归到基准值（场景里的 fov 可能被别处改过）。
func bind(camera: Camera3D) -> void:
	_camera = camera
	if _camera != null:
		_camera.fov = BASE_FOV

## 进入/退出开镜。返回是否真的发生了切换（重复调用返回 false，不发信号）。
## tree 由调用方传 get_tree() —— 本层是 RefCounted，没有节点上下文。
func set_aiming(on: bool, tree: SceneTree) -> bool:
	if on == aiming:
		return false
	aiming = on
	_apply_fov(tree, ADS_FOV if on else BASE_FOV)
	EventBus.ads_changed.emit(on)
	return true

## 每帧推进 blend。HUD 也可以直接读 blend，不强制连信号。
func tick(delta: float) -> void:
	var target: float = 1.0 if aiming else 0.0
	blend = move_toward(blend, target, delta / maxf(ADS_TIME, 0.001))

## 当前灵敏度乘数（1.0 = 腰射，ADS_SENS = 完全开镜）
func sensitivity_scale() -> float:
	return lerpf(1.0, ADS_SENS, blend)

func spread_scale() -> float:
	return lerpf(1.0, ADS_SPREAD, blend)

func recoil_scale() -> float:
	return lerpf(1.0, ADS_RECOIL, blend)

func reset() -> void:
	aiming = false
	blend = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _camera != null:
		_camera.fov = BASE_FOV

## FOV 过渡。旧 tween 必须先 kill，否则多条 tween 抢同一个 fov。
func _apply_fov(tree: SceneTree, target_fov: float) -> void:
	if _camera == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if tree == null:
		_camera.fov = target_fov
		return
	_tween = tree.create_tween()
	_tween.tween_property(_camera, "fov", target_fov, ADS_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
