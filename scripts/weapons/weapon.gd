## 武器运行时节点（射击 / 弹药 / 换弹 / 切枪）
## class_name: Weapon
## 挂载节点类型: Node3D（挂在 Player 的 Camera3D 下的 WeaponMount 上）
## 依赖信号:
##   监听 —— 无（由 Player 直接调用 try_fire / start_reload / cancel_reload）
##   发出 —— EventBus.player_fired / ammo_changed / reload_started /
##           reload_cancelled / reload_finished / zombie_hit / bullet_impact
## 节点路径假设:
##   - 自身是 Node3D，global_transform 即枪口参考；不需要 Muzzle 子节点（射线从
##     摄像机中心出，符合 FPS 准星语义）。
##   - @export muzzle_offset 沿本地 -Z 偏移，用于枪口火焰定位（美术侧可覆盖）。
##   - @export shooter_path 指向持有本武器的 Player（用于射线 exclude 自身 RID）。
## 与 PDF 的对应:
##   - "弹匣容量与备弹量构成资源管理，换弹时机是核心博弈点" → 换弹可被打断，
##     逐发装填武器（霰弹枪/狙击枪）支持中途开火中断。
##   - "武器三层：现实军械 / 科研特制 / BA 道具" → 由 WeaponData.weapon_class 区分。
## 关键修复（相对旧骨架）:
##   1. 射线排除自身：旧代码 query.exclude = [get_owner()] 传 Node，Godot 4 要求
##      Array[RID]，运行时会报 "Invalid type in array"。改用 [shooter.get_rid()]。
##   2. pellets / spread_degrees 旧代码声明未使用 → 现在每颗弹丸独立随机散布，
##      霰弹枪真正打出 8~10 颗。
class_name Weapon
extends Node3D

## 射线解算层（散布 / 命中 / 弱点 / 金属归类）。
## 单向依赖：ballistics 不引用本文件，不会形成 Cyclic reference。
const Ballistics := preload("res://scripts/weapons/weapon_ballistics.gd")

## 换弹被打断的原因（供 HUD 区分提示文案）
enum ReloadCancelReason { SWITCH, DEATH, MANUAL }

@export var data: WeaponData
## 持有者（Player）。用于射线 exclude 与伤害来源归属。
@export var shooter_path: NodePath
## 枪口沿本地 -Z 的偏移（纯表现用，射线永远从摄像机中心出）
@export var muzzle_offset: float = 0.6
## 备用弹药拾取上限是否受 max_reserve_ammo 限制
@export var clamp_reserve: bool = true

var _shooter: Node3D
var _mag_ammo: int = 0
var _reserve_ammo: int = 0
var _cooldown: float = 0.0            ## 距下一发可射的剩余秒数
var _reload_left: float = 0.0         ## 换弹剩余秒数
var _is_reloading: bool = false
var _burst_left: int = 0              ## 点射剩余发数
var _burst_timer: float = 0.0
var _trigger_held: bool = false
## 开镜状态。只改散布与后坐乘数 —— 射线起点/朝向永远取摄像机中心，
## 与 WeaponMount 的位置无关，所以 ADS 不需要动枪口。
var _ads_on: bool = false
var _ads_spread: float = 1.0
var _ads_recoil: float = 1.0
## 在飞的弹丸（仅 muzzle_velocity > 0 时非空）。
## 为什么放在 Weapon 而不是全局管理器：弹丸的射程/伤害/排除体全部来自本武器，
## 换枪时正在飞的子弹也不该被别的枪接管 —— 生命周期跟着开火者走最短。
var _projectiles: Array[WeaponProjectile] = []

func _ready() -> void:
	if data == null:
		push_error("Weapon[%s]: data 未赋值，武器不可用。" % name)
		set_process(false)
		return
	for issue: String in data.validate():
		push_warning("Weapon[%s] 配置问题: %s" % [name, issue])
	_mag_ammo = data.magazine_size
	_reserve_ammo = data.reserve_ammo
	if not shooter_path.is_empty():
		_shooter = get_node_or_null(shooter_path) as Node3D
	if _shooter == null:
		_shooter = _find_shooter()
	# 这里不再广播弹药：同一 Player 下多把枪各自 deferred 广播会互相覆盖
	# （实测槽位 0 显示成霰弹枪的 6/24）。弹药状态的唯一广播点是
	# Player._equip()（切枪时）与武器自身的开火/换弹/拾取动作。

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	if _is_reloading:
		_tick_reload(delta)
	_tick_projectiles(delta)
	# 全自动：按住即连发；点射：按 burst 节奏续发
	if _trigger_held:
		if data.fire_mode == WeaponData.FireMode.FULL_AUTO:
			try_fire()
		elif data.fire_mode == WeaponData.FireMode.BURST and _burst_left > 0:
			_burst_timer -= delta
			if _burst_timer <= 0.0:
				_fire_one_round()
				_burst_left -= 1
				_burst_timer = data.shot_interval()

## 推进在飞的弹丸。倒序遍历 —— advance 返回 true 时要原地移除，
## 正序遍历会在 remove_at 后跳过一个元素。
func _tick_projectiles(delta: float) -> void:
	if _projectiles.is_empty():
		return
	var world: World3D = get_world_3d()
	for i: int in range(_projectiles.size() - 1, -1, -1):
		if _projectiles[i].advance(world, delta):
			_projectiles.remove_at(i)

# ── 输入入口（由 Player 转发）────────────────────────────────────

## 按下扳机
func pull_trigger() -> void:
	_trigger_held = true
	if data == null:
		return
	match data.fire_mode:
		WeaponData.FireMode.SEMI_AUTO:
			try_fire()
		WeaponData.FireMode.BURST:
			if _burst_left <= 0:
				_burst_left = data.burst_count
				_burst_timer = 0.0
		WeaponData.FireMode.FULL_AUTO:
			try_fire()

## 松开扳机
func release_trigger() -> void:
	_trigger_held = false

## 尝试开火。返回是否真的打出一发。
func try_fire() -> bool:
	if data == null or _cooldown > 0.0 or _is_reloading:
		return false
	if _mag_ammo <= 0:
		# 空仓自动换弹（PDF：换弹时机是核心博弈点，自动换弹降低空枪惩罚）
		EventBus.player_dry_fire.emit()
		start_reload()
		return false
	_fire_one_round()
	return true

## 开始换弹。返回是否真的开始。
func start_reload() -> bool:
	if data == null or _is_reloading:
		return false
	if _mag_ammo >= data.magazine_size or _reserve_ammo <= 0:
		return false
	_is_reloading = true
	_burst_left = 0
	_reload_left = data.effective_reload_time()
	EventBus.reload_started.emit(_reload_left)
	return true

## 打断换弹（切枪 / 死亡 / 手动取消）
func cancel_reload(reason: int = ReloadCancelReason.MANUAL) -> void:
	if not _is_reloading:
		return
	_is_reloading = false
	_reload_left = 0.0
	EventBus.reload_cancelled.emit()

## 补充备弹（弹药拾取调用）。返回实际补充量。
func add_reserve(amount: int) -> int:
	if data == null or amount <= 0:
		return 0
	var cap: int = data.max_reserve_ammo if clamp_reserve else 999999
	var before: int = _reserve_ammo
	_reserve_ammo = mini(_reserve_ammo + amount, cap)
	var gained: int = _reserve_ammo - before
	if gained > 0:
		_broadcast_ammo()
	return gained

# ── 查询 ────────────────────────────────────────────────────────

func mag_ammo() -> int:
	return _mag_ammo

func reserve_ammo() -> int:
	return _reserve_ammo

func is_reloading() -> bool:
	return _is_reloading

## 换弹进度 0.0~1.0（HUD 进度条用）
func reload_progress() -> float:
	if not _is_reloading or data == null:
		return 0.0
	var total: float = data.effective_reload_time()
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _reload_left / total, 0.0, 1.0)

## 枪口世界坐标（枪火特效挂点）
func muzzle_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, -muzzle_offset)

## 开镜开关。只影响散布与后坐，不影响射线起点（永远从摄像机中心出）。
## 后坐乘数只在这里乘一次：Player._on_weapon_fired 若再乘会双重衰减。
func set_ads(on: bool, spread_scale: float = 1.0, recoil_scale: float = 1.0) -> void:
	_ads_on = on
	_ads_spread = clampf(spread_scale, 0.0, 4.0) if on else 1.0
	_ads_recoil = clampf(recoil_scale, 0.0, 4.0) if on else 1.0

func is_ads() -> bool:
	return _ads_on

# ── 射击核心 ────────────────────────────────────────────────────

func _fire_one_round() -> void:
	_mag_ammo -= 1
	_cooldown = data.shot_interval()
	_broadcast_ammo()

	var origin: Vector3 = _ray_origin()
	var basis: Basis = _ray_basis()
	var pellet_count: int = maxi(data.pellets, 1)
	for i: int in pellet_count:
		_fire_pellet(origin, basis)
	EventBus.player_fired.emit(data, data.recoil * _ads_recoil)

	# 空仓后自动进入换弹
	if _mag_ammo <= 0:
		start_reload()

func _fire_pellet(origin: Vector3, basis: Basis) -> void:
	# 单发解算（散布采样 + 射线 + 命中归类）委托给 weapon_ballistics.gd。
	# 拆分动机：PDF 硬红线单文件 ≤ 300 行，本文件补齐散布/弱点/金属判定后到 327 行。
	# 本层只留"状态机"（弹药/冷却/换弹/连发节奏），解算层是纯函数无状态。
	#
	# 两条路径（用户 m09845 要求「子弹初速真实」）：
	#   muzzle_velocity <= 0 → 瞬时命中，一发一条满射程射线，零额外分配。
	#   muzzle_velocity > 0  → 生成一颗在飞弹丸，逐帧按 v*dt 推进，
	#                          命中延迟 = 实际飞行距离 / 初速。
	# 为什么不是「永远走弹道」：15 米内 380m/s 只差 39ms（2~3 帧），
	# 感知不到；而霰弹枪 8 颗弹丸每帧一条射线 × 15 帧 = 120 次查询，
	# 纯浪费算力。所以初速是每把枪的开关，不是全局强制。
	if data.muzzle_velocity > 0.0:
		_projectiles.append(WeaponProjectile.spawn(
			data, origin, -basis.z, _shooter, _exclude_rids(), _ads_spread))
		return
	Ballistics.fire_pellet(get_world_3d(), data, origin, basis, _exclude_rids(), _shooter,
		_ads_spread)

## 射线起点：优先摄像机中心（准星即命中点），无摄像机时退回自身
func _ray_origin() -> Vector3:
	var cam: Camera3D = _active_camera()
	return cam.global_position if cam != null else global_position

func _ray_basis() -> Basis:
	var cam: Camera3D = _active_camera()
	return cam.global_transform.basis if cam != null else global_transform.basis

func _active_camera() -> Camera3D:
	if _shooter == null:
		return null
	if _shooter is Camera3D:
		return _shooter as Camera3D
	return _shooter.get_viewport().get_camera_3d()

## Godot 4 要求 Array[RID]，旧骨架传 Node 是硬伤。
## 保留在状态机层（不进 ballistics）：它读 _shooter 成员，
## 而 ballistics 是纯函数层，不持有也不读任何武器状态。
func _exclude_rids() -> Array[RID]:
	var out: Array[RID] = []
	if _shooter != null and _shooter is CollisionObject3D:
		out.append((_shooter as CollisionObject3D).get_rid())
	return out

func _find_shooter() -> Node3D:
	var node: Node = get_parent()
	while node != null:
		if node.is_in_group(GameLayers.GROUP_PLAYER):
			return node as Node3D
		node = node.get_parent()
	return null

# ── 换弹推进 ────────────────────────────────────────────────────

func _tick_reload(delta: float) -> void:
	_reload_left -= delta
	if _reload_left > 0.0:
		return
	_finish_reload_step()

## 逐发装填武器每完成一段只装 1 发并继续；整匣武器一次装满。
func _finish_reload_step() -> void:
	var need: int = data.magazine_size - _mag_ammo
	var available: int = mini(need, _reserve_ammo)
	if available <= 0:
		_is_reloading = false
		_reload_left = 0.0
		EventBus.reload_finished.emit()
		return
	if data.reload_per_shell:
		_mag_ammo += 1
		_reserve_ammo -= 1
		_broadcast_ammo()
		if _mag_ammo < data.magazine_size and _reserve_ammo > 0:
			# 单发装填时长 = 总时长 / 弹匣容量
			_reload_left = data.effective_reload_time() / float(data.magazine_size)
			EventBus.reload_started.emit(_reload_left)
			return
	else:
		_mag_ammo += available
		_reserve_ammo -= available
		_broadcast_ammo()
	_is_reloading = false
	_reload_left = 0.0
	EventBus.reload_finished.emit()

func _broadcast_ammo() -> void:
	EventBus.ammo_changed.emit(_mag_ammo, _reserve_ammo)

## 池化 / 关卡重置用：恢复初始弹药
func reset_ammo() -> void:
	if data == null:
		return
	_mag_ammo = data.magazine_size
	_reserve_ammo = data.reserve_ammo
	_is_reloading = false
	_reload_left = 0.0
	_cooldown = 0.0
	_burst_left = 0
	_trigger_held = false
	_broadcast_ammo()
