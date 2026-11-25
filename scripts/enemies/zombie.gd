## 丧尸 AI（生成 / 追击 / 攻击 / 死亡）
## class_name: Zombie
## 挂载节点类型: CharacterBody3D
## 依赖信号:
##   监听 —— HealthComponent.damaged / HealthComponent.died
##   发出 —— EventBus.zombie_died / EventBus.execution_slowmo（弱点击杀处决镜头）
## 节点路径与池化复位契约见父类 scripts/enemies/zombie_base.gd。
## PDF 对应:
##   - 纸片人 billboard → 绝不对 Sprite3D 做 look_at，只翻 flip_h 表现朝向。
##   - 「围堵包抄，高密度」→ 分离力让 60 只不重叠，天然形成包抄弧。
##   - 「处决 time_scale 0.25 / 0.4~0.6 秒」→ 弱点击杀广播 execution_slowmo，
##     时间缩放由 GameManager 统一控制（本脚本不直接改 Engine.time_scale）。
## 关键修复（相对旧骨架）: ①`_target.is_alive()` 对 Node3D 静态调用报错 →
##   ZombieSteering.node_alive 用 has_method 守卫；②找池从硬编码分组名改为
##   pool_path + 父链 + GROUP_POOL 三级兜底；③删 look_at，改 sprite_flip_h。
class_name Zombie
extends ZombieBase

@export_group("战斗")
@export var acceleration: float = 18.0
@export var attack_damage: float = 12.0
@export var attack_range: float = 1.6
@export var attack_interval: float = 1.2
## 进入攻击距离前的提前量，避免贴脸才抬手
@export var attack_windup: float = 0.25
@export var stagger_time: float = 0.25
@export var gravity_scale: float = 1.0

@export_group("感知")
## 失去目标视线多久后放弃追击（秒）
@export var lose_target_time: float = 6.0
## 丧尸之间的分离半径（防重叠，形成包抄弧线）
@export var separation_radius: float = 1.1
@export var separation_strength: float = 4.0

@export_group("处决镜头")
## 弱点击杀触发慢动作的概率（0 = 关闭）
@export var execution_chance: float = 0.35
## 慢动作时长（PDF: 0.4~0.6 秒）
@export var execution_duration: float = 0.5

var _target: Node3D
var _attack_cooldown: float = 0.0
var _lose_timer: float = 0.0
var _last_hit_was_weakspot: bool = false
## 死亡动画剩余展示时间。倒计时结束才回池，否则尸体瞬间消失、death 帧根本播不到。
var _death_left: float = 0.0

## death 动画 5 帧 @ 6fps ≈ 0.83s，留 0.12s 余量让最后一帧（完全倒地）被看见。
const DEATH_ANIM_HOLD := 0.95

func _ready() -> void:
	_capture_base_stats()
	add_to_group(GameLayers.GROUP_ZOMBIE)
	# PackedScene 不序列化运行时 add_to_group 的结果，场景里配的组在实例化后会丢，
	# 必须在 _ready 幂等补一次，否则 Weapon 的弱点判定永远为 false。
	_ensure_weakspot_group()
	collision_layer = GameLayers.ZOMBIE
	collision_mask = GameLayers.MASK_ZOMBIE_BODY
	if _health != null:
		_health.max_health = max_health
		_health.reset_health()
		_health.damaged.connect(_on_damaged)
		_health.died.connect(_on_died)
	if _agent != null:
		_agent.path_desired_distance = 0.8
		_agent.target_desired_distance = attack_range * 0.8
	_resolve_pool()

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_tick_timers(delta)
	_acquire_target()
	match _state:
		State.IDLE:
			_tick_idle(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.STAGGER:
			_tick_stagger(delta)
	_apply_gravity(delta)
	move_and_slide()
	_update_sprite_facing()
	_sync_anim()

## 死亡后物理已停（_physics_process 早退），靠 _process 把倒地动画放完再回池。
func _process(delta: float) -> void:
	if _state != State.DEAD or _death_left <= 0.0:
		return
	_death_left = maxf(_death_left - delta, 0.0)
	if _death_left <= 0.0:
		_return_to_pool()

## 把 AI 状态映射到精灵帧动画。ATTACK 是非循环的 3 帧，播完后重放，
## 否则两次攻击之间会僵在最后一帧的伸爪姿势上。
func _sync_anim() -> void:
	if _sprite == null or not _sprite.has_method(&"play"):
		return
	match _state:
		State.IDLE:
			_sprite.call(&"play", &"idle")
		State.CHASE:
			_sprite.call(&"play", &"walk")
		State.ATTACK:
			if bool(_sprite.call(&"is_anim_done")):
				_sprite.call(&"play", &"attack", true)
			else:
				_sprite.call(&"play", &"attack")
		State.STAGGER:
			_sprite.call(&"play", &"hurt")

# ── 状态推进 ────────────────────────────────────────────────────

func _tick_idle(delta: float) -> void:
	_decelerate(delta)
	if _target != null:
		_enter_state(State.CHASE)

func _tick_chase(delta: float) -> void:
	if _target == null:
		_enter_state(State.IDLE)
		return
	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist <= attack_range:
		_enter_state(State.ATTACK)
		return
	var desired_dir: Vector3 = ZombieSteering.chase_direction(
		_agent,
		global_position,
		_target.global_position,
		ZombieSteering.separation(
			global_position, self,
			get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE),
			separation_radius,
		),
		separation_strength,
	)
	_accelerate_toward(desired_dir * move_speed, delta)

func _tick_attack(delta: float) -> void:
	_decelerate(delta)
	if _target == null:
		_enter_state(State.IDLE)
		return
	# 攻击瞬间只转身不移动（纸片人 billboard，转身只影响 flip_h）
	var flat: Vector3 = _target.global_position - global_position
	flat.y = 0.0
	if flat.length() > attack_range * 1.35:
		_enter_state(State.CHASE)
		return
	if _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
		_strike()

func _tick_stagger(delta: float) -> void:
	# 被推挤时击退位移优先 —— 否则 _decelerate 会立刻吃掉击退速度，推了等于没推
	if not _integrate_shove(delta):
		_decelerate(delta)

func _enter_state(next: State) -> void:
	if _state == next:
		return
	_state = next

func _tick_timers(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _stagger_left > 0.0:
		_stagger_left = maxf(_stagger_left - delta, 0.0)
		if _stagger_left <= 0.0 and _state == State.STAGGER:
			_enter_state(State.CHASE)
	if _target != null:
		if _has_line_of_sight():
			_lose_timer = 0.0
		else:
			_lose_timer += delta
			if _lose_timer >= lose_target_time:
				_target = null

# ── 移动 ────────────────────────────────────────────────────────

func _accelerate_toward(desired: Vector3, delta: float) -> void:
	velocity = ZombieSteering.steer_horizontal(velocity, desired, acceleration, delta)

func _decelerate(delta: float) -> void:
	velocity = ZombieSteering.steer_horizontal(velocity, Vector3.ZERO, acceleration, delta)

func _apply_gravity(delta: float) -> void:
	velocity = ZombieSteering.apply_gravity(velocity, is_on_floor(), gravity_scale, delta)

## billboard 精灵不转向；只按目标在左/右决定 flip_h（计算已迁至 ZombieSteering）
func _update_sprite_facing() -> void:
	if _sprite == null or _target == null:
		return
	ZombieSteering.sprite_flip_h(
		_sprite,
		get_viewport().get_camera_3d(),
		global_position,
		_target.global_position,
	)

# ── 目标 / 感知 ─────────────────────────────────────────────────

func _acquire_target() -> void:
	if _target_valid():
		return
	_target = null
	var best: Node3D = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_PLAYER):
		var candidate: Node3D = node as Node3D
		if candidate == null:
			continue
		if not ZombieSteering.node_alive(candidate):
			continue
		var d: float = global_position.distance_squared_to(candidate.global_position)
		if d < best_dist:
			best_dist = d
			best = candidate
	if best != null:
		_target = best
		_lose_timer = 0.0

func _target_valid() -> bool:
	if _target == null:
		return false
	return ZombieSteering.node_alive(_target)

func _has_line_of_sight() -> bool:
	if _target == null:
		return false
	return ZombieSteering.has_line_of_sight(
		get_world_3d(),
		get_rid(),
		global_position + Vector3.UP * 1.0,
		_target.global_position + Vector3.UP * 1.0,
		_target,
		GameLayers.MASK_HITSCAN,
	)

# ── 攻击 ────────────────────────────────────────────────────────

func _strike() -> void:
	if _target == null:
		return
	if not _target.has_method(&"take_damage"):
		return
	_target.call(&"take_damage", attack_damage, false, self)

# ── 受击 / 死亡 ─────────────────────────────────────────────────

func _on_damaged(_amount: float, _is_fatal: bool, _source: Node) -> void:
	if _state == State.DEAD:
		return
	if _stagger_left <= 0.0 and stagger_time > 0.0:
		_stagger_left = stagger_time
		_enter_state(State.STAGGER)

## 统一受击入口。签名与 Player.take_damage 一致。
func take_damage(amount: float, is_weakspot: bool = false, source: Node = null) -> float:
	if _state == State.DEAD or _health == null:
		return 0.0
	_last_hit_was_weakspot = is_weakspot
	# 弱点命中强制硬直，给玩家反馈
	if is_weakspot and stagger_time > 0.0:
		_stagger_left = stagger_time * 1.6
		_enter_state(State.STAGGER)
	return _health.apply_damage(amount, source)

func _on_died(source: Node) -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector3.ZERO
	if _sprite != null and _sprite.has_method(&"play"):
		_sprite.call(&"play", &"death", true)
	# 物理停掉（不再推进/碰撞），但保留 _process 让倒地帧播完
	set_physics_process(false)
	_death_left = DEATH_ANIM_HOLD
	if _last_hit_was_weakspot and execution_chance > 0.0 and randf() < execution_chance:
		EventBus.execution_slowmo.emit(execution_duration)
	EventBus.zombie_died.emit(self, source)

## 出池 / 回池时复位 AI 变量（由 ZombieBase._on_pool_acquired/_on_pool_released 调用）
func _reset_spawn_state() -> void:
	_target = null
	_attack_cooldown = attack_interval * 0.5
	_stagger_left = 0.0
	_lose_timer = 0.0
	_last_hit_was_weakspot = false
	_death_left = 0.0
	if _sprite != null and _sprite.has_method(&"play"):
		_sprite.call(&"play", &"idle", true)
