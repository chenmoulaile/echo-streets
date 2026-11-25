## 玩家 FPS 控制器（WASD 移动 / 鼠标视角 / 射击 / 血量 / 切枪 / 开镜 / 推挤）
## class_name: Player
## 挂载节点类型: CharacterBody3D
## 依赖信号:
##   监听 —— 自身 HealthComponent 的 health_changed / damaged / died
##   发出 —— 全部经 EventBus 转发（player_health_changed / player_hit /
##           player_died / weapon_switched），不向父节点直连
## 节点路径假设（场景树结构）:
##   Player                (CharacterBody3D, 本脚本, group "Player")
##   ├── CollisionShape3D  (CapsuleShape3D, 高 1.8, 半径 0.4)
##   ├── HealthComponent   (Node, 挂 health_component.gd)      ← health_path
##   ├── CameraRig         (Node3D, 位于 y=1.6, 只做视角, 不随身体旋转)  ← camera_rig_path
##   │   └── Camera3D      (fov 75, current=true)              ← camera_path
##   │       └── WeaponMount (Node3D, 位于 (0.3,-0.25,-0.5))   ← weapon_mount_path
##   │           ├── Pistol  (Node3D, 挂 weapon.gd, data=手枪.tres)
##   │           └── Shotgun (Node3D, 挂 weapon.gd, data=霰弹枪.tres)
##   └── (可选) CrouchShape / 脚步声 AudioStreamPlayer3D
## 与 PDF 的对应:
##   - "Doom 式伪 3D：3D 场景 + 2D 像素枪械 HUD" → 武器逻辑在 3D，表现交给 HUD 层。
##   - "换弹时机是核心博弈点" → 切枪会打断换弹（cancel_reload），玩家需自行权衡。
## 职责边界（本文件只做这些，其余全下沉，守 PDF 单文件 ≤ 300 行红线）:
##   移动 / 视角 / 血量 / 复活编排。开镜→player_aim.gd，推挤→player_shove.gd，
##   战斗输入分派→player_combat_input.gd，武器槽→player_arsenal.gd。
## 关键修复（相对旧骨架）:
##   旧代码 `velocity.x = move_toward(velocity.x, 0.0, move_speed)` 每帧按固定量减速，
##   帧率相关且量纲错误（拿速度当减速度）。现改为 accel/decel 乘 delta 的线性逼近。
class_name Player
extends CharacterBody3D

## 处决慢动作倍率（PDF 规定 0.25）
const SLOWMO_RECOVERY := 0.25

## 血量与击杀回复策略层（预算状态 + 死亡清理）。
## 拆分动机：PDF 硬红线单文件 ≤ 300 行，本文件补齐无敌帧与回复预算后到 316 行。
const Vitals := preload("res://scripts/player/player_vitals.gd")
## 视角/后坐数学层（俯仰钳制 + 后坐回正）。拆分理由同上：行数红线。
const Look := preload("res://scripts/player/player_look.gd")
## 武器槽管理（收集 / 切换 / 循环 / 重置）。拆分理由同上：行数红线。
const Arsenal := preload("res://scripts/player/player_arsenal.gd")
## 开镜策略层（FOV 过渡 + 灵敏度/散布/后坐乘数）。拆分理由同上：行数红线。
const Aim := preload("res://scripts/player/player_aim.gd")
## 推挤结算层（前方扇形判定 + 击退派发）。拆分理由同上：行数红线。
const Shove := preload("res://scripts/player/player_shove.gd")
## 战斗输入分派（fire / aim / bash / reload / 切枪）。
## 签名只收 Node3D + RefCounted，不收 Player —— 否则与本文件形成 Cyclic reference。
const CombatInput := preload("res://scripts/player/player_combat_input.gd")

@export_group("移动")
@export var move_speed: float = 6.0
@export var sprint_multiplier: float = 1.5
@export var crouch_multiplier: float = 0.5
## 加速度（米/秒²）。越大手感越"脆"，越小越"滑"。
@export var acceleration: float = 60.0
@export var deceleration: float = 70.0
@export var air_control: float = 0.25
@export var jump_velocity: float = 5.0
@export var gravity_scale: float = 1.0

@export_group("视角")
@export var mouse_sensitivity: float = 0.0022
## 玩家偏好的灵敏度倍率（来自设置面板存档）。与 mouse_sensitivity 相乘。
@export var sensitivity_scale: float = 1.0
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0
## 后坐力回正速度（度/秒）
@export var recoil_recovery: float = 12.0

@export_group("战斗")
## 受击后无敌帧秒数（防止 60 只丧尸同帧叠伤秒杀）
@export var hit_invulnerable_time: float = 0.35
## 击杀回复（PDF 词条"战地医疗包：击杀回 2 血，每秒上限 20"）
@export var kill_heal_amount: float = 0.0
@export var kill_heal_per_second_cap: float = 20.0

@export_group("节点路径")
@export var health_path: NodePath = ^"HealthComponent"
@export var camera_rig_path: NodePath = ^"CameraRig"
@export var camera_path: NodePath = ^"CameraRig/Camera3D"
@export var weapon_mount_path: NodePath = ^"CameraRig/Camera3D/WeaponMount"

@onready var _health: HealthComponent = get_node_or_null(health_path) as HealthComponent
@onready var _camera_rig: Node3D = get_node_or_null(camera_rig_path) as Node3D
@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _weapon_mount: Node3D = get_node_or_null(weapon_mount_path) as Node3D

var _pitch: float = 0.0
var _recoil_pitch: float = 0.0
## 武器槽管理（收集 / 切换 / 循环）。逻辑在 player_arsenal.gd。
var _arsenal: RefCounted = Arsenal.new()
## 开镜状态与三个乘数。逻辑在 player_aim.gd。
var _aim: RefCounted = Aim.new()
## 推挤冷却与命中结算。逻辑在 player_shove.gd。
var _shove: RefCounted = Shove.new()
var _is_dead: bool = false
## 击杀回复预算（PDF 词条"击杀回 2 血、每秒上限 20"）。逻辑在 player_vitals.gd。
var _vitals: RefCounted = Vitals.new()

func _ready() -> void:
	InputSetup.ensure_defaults()
	# 持久化的操控方案必须在这里真正绑到 InputMap 上，否则重启后回到默认方案。
	GameSettings.apply_all()
	sensitivity_scale = GameSettings.sensitivity
	add_to_group(GameLayers.GROUP_PLAYER)
	collision_layer = GameLayers.PLAYER
	collision_mask = GameLayers.MASK_PLAYER_BODY
	floor_max_angle = deg_to_rad(46.0)
	_collect_weapons()
	_connect_health()
	# 把 @export 的回复参数灌进策略层（导出项由场景覆盖，不能写死在 vitals 里）
	_vitals.heal_amount = kill_heal_amount
	_vitals.heal_per_second_cap = kill_heal_per_second_cap
	_aim.bind(_camera)
	EventBus.zombie_died.connect(_on_zombie_died)
	EventBus.player_fired.connect(_on_weapon_fired)
	EventBus.input_scheme_changed.connect(_on_scheme_changed)
	_equip(0, true)

func _exit_tree() -> void:
	if EventBus.zombie_died.is_connected(_on_zombie_died):
		EventBus.zombie_died.disconnect(_on_zombie_died)
	if EventBus.player_fired.is_connected(_on_weapon_fired):
		EventBus.player_fired.disconnect(_on_weapon_fired)
	if EventBus.input_scheme_changed.is_connected(_on_scheme_changed):
		EventBus.input_scheme_changed.disconnect(_on_scheme_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		# 灵敏度 = 基础 × 玩家偏好 × 开镜收窄。三个乘数相乘，顺序无关，
		# 但必须都在这里一次算完 —— 分散到两处会漏乘。
		var sens: float = mouse_sensitivity * sensitivity_scale * _aim.sensitivity_scale()
		_rotate_view(-motion.relative.x * sens, -motion.relative.y * sens)
		return
	CombatInput.handle(event, self, _arsenal, _aim, _shove)

func _physics_process(delta: float) -> void:
	_tick_kill_heal_budget(delta)
	_aim.tick(delta)
	_shove.tick(delta)
	if _is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_apply_gravity(delta)
	_apply_movement(delta)
	move_and_slide()
	_tick_recoil(delta)

# ── 移动 ────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * gravity_scale * delta

func _apply_movement(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	# 移动方向只跟身体朝向（yaw），不跟镜头俯仰
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	direction.y = 0.0
	direction = direction.normalized()

	var target_speed: float = _target_speed()
	var desired: Vector3 = direction * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	# 帧率无关：accel * delta 线性逼近目标速度
	var rate: float = acceleration
	if direction.length_squared() < 0.01:
		rate = deceleration
	if not is_on_floor():
		rate *= air_control
	horizontal = horizontal.move_toward(desired, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

func _target_speed() -> float:
	var speed: float = move_speed
	if Input.is_action_pressed(&"sprint"):
		speed *= sprint_multiplier
	if Input.is_action_pressed(&"crouch"):
		speed *= crouch_multiplier
	return speed

# ── 视角 ────────────────────────────────────────────────────────

func _rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	rotate_y(yaw_delta)
	var r: Array = Look.apply_look(_pitch, _recoil_pitch, pitch_delta, pitch_min, pitch_max)
	_pitch = r[0]
	if _camera_rig != null:
		_camera_rig.rotation.x = _pitch + _recoil_pitch
	elif _camera != null:
		_camera.rotation.x = _pitch + _recoil_pitch

func _tick_recoil(delta: float) -> void:
	var r: Array = Look.tick_recoil(_recoil_pitch, delta, recoil_recovery)
	_recoil_pitch = r[0]
	if not r[1]:
		return
	var node: Node3D = _camera_rig if _camera_rig != null else _camera
	if node != null:
		node.rotation.x = _pitch + _recoil_pitch

func _on_weapon_fired(_weapon_data: Resource, recoil: float) -> void:
	# 后坐力只抬镜头，不改变实际射线方向（保证准星诚实）。
	# 开镜衰减已在 Weapon 侧乘过（_ads_recoil），这里再乘就是平方衰减。
	_recoil_pitch = Look.add_recoil(_recoil_pitch, recoil)

# ── 武器 ────────────────────────────────────────────────────────

func _collect_weapons() -> void:
	if _weapon_mount == null:
		push_warning("Player: weapon_mount_path 未解析到节点，玩家无法开火。")
		return
	if not _arsenal.collect(_weapon_mount):
		push_warning("Player: WeaponMount 下没有任何 Weapon 子节点。")

func _current_weapon() -> Weapon:
	return _arsenal.current()

## 当前手持武器（供 UI 在接线后主动拉取初始状态）。
## 存在理由：_ready 里的 _equip(0, true) 会同步发 weapon_switched，而 HUD 的
## _ready 更晚（节点顺序上 Hud 在 Player 之后），那条信号会被直接丢弃 ——
## 只靠推模型会导致 HUD 的枪械贴图永远是空的。
func active_weapon() -> Weapon:
	return _arsenal.current()

## 当前武器槽位下标
func active_slot() -> int:
	return _arsenal.index

## 是否正在开镜（供 HUD 拉取初始状态，信号之外的第二条路）
func is_aiming() -> bool:
	return _aim.aiming

func _equip(index: int, force: bool = false) -> void:
	_arsenal.equip(index, force)
	# 开镜中切枪：新枪不知道玩家在开镜，散布会突然变大，必须重灌乘数。
	CombatInput.resync_ads(_arsenal, _aim)

func _cycle_weapon(step: int) -> void:
	_arsenal.cycle(step)
	CombatInput.resync_ads(_arsenal, _aim)

## 操控方案切换后重新应用灵敏度（方案本身由 InputMap 处理，本函数只管玩法侧）
func _on_scheme_changed(_scheme: int) -> void:
	sensitivity_scale = GameSettings.sensitivity

# ── 血量 ────────────────────────────────────────────────────────

func _connect_health() -> void:
	if _health == null:
		push_warning("Player: health_path 未解析到 HealthComponent，玩家将不会受伤。")
		return
	_health.max_health = maxf(_health.max_health, 1.0)
	_health.invulnerable_time = hit_invulnerable_time
	# 子节点 _ready 早于本节点，改完 max_health 需重置内部当前值保持一致
	_health.reset_health()
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)

## 供丧尸 / 爆炸调用。签名与 Weapon 的 take_damage 保持一致便于统一处理。
func take_damage(amount: float, _is_weakspot: bool = false, source: Node = null) -> float:
	if _health == null or _is_dead:
		return 0.0
	var dealt: float = _health.apply_damage(amount, source)
	if dealt > 0.0:
		EventBus.player_hit.emit(dealt, source)
	return dealt

func heal(amount: float) -> float:
	return _health.heal(amount) if _health != null else 0.0

func is_alive() -> bool:
	return not _is_dead

func _on_health_changed(current: float, max_value: float) -> void:
	EventBus.player_health_changed.emit(current, max_value)

func _on_died(_source: Node) -> void:
	_is_dead = true
	# 打断换弹 + 松开扳机 + 交还鼠标：三条收在 player_vitals.gd，
	# 这里只剩"标记死亡 + 广播"。
	Vitals.handle_death(_current_weapon())
	_aim.reset()
	EventBus.player_died.emit()

# ── 击杀回复（PDF 强化词条约束：每秒上限）──────────────────────────

func _tick_kill_heal_budget(delta: float) -> void:
	_vitals.tick(delta)

func _on_zombie_died(_zombie: Node, killer: Node) -> void:
	if killer != self or _is_dead:
		return
	_vitals.on_kill(heal)

## 关卡重置 / 复活
func reset_player() -> void:
	_is_dead = false
	_pitch = 0.0
	_recoil_pitch = 0.0
	velocity = Vector3.ZERO
	if _health != null:
		_health.reset_health()
	_arsenal.reset_all()
	_vitals.reset()
	_aim.reset()
	_shove.reset()
	_equip(0, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
