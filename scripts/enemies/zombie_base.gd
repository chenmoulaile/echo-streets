## 丧尸池化基类（基础属性 + 对象池生命周期 + 状态自省）
## class_name: ZombieBase
## 挂载节点类型: CharacterBody3D
## 拆出理由: zombie.gd 原 341 行超出 PDF「单文件不超过 300 行」红线。
##   池化复位与自省接口语义独立、不依赖 AI 状态机，单独成类不改变任何外部契约。
## 子类契约:
##   - 子类 _ready() 首行调用 _capture_base_stats() 记录基准值
##   - 子类覆盖 _reset_spawn_state() 复位自己的 AI 变量
## 节点路径假设:
##   ZombieBase           (CharacterBody3D, 本脚本)
##   ├── HealthComponent  (health_component.gd)              ← health_path
##   ├── Sprite3D         (billboard=enabled, filter=Nearest) ← sprite_path
##   └── NavigationAgent3D(可选, 有 NavigationRegion3D 时挂)  ← agent_path
class_name ZombieBase
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, STAGGER, DEAD }

@export_group("属性")
@export var max_health: float = 100.0
@export var move_speed: float = 2.4

@export_group("节点路径")
@export var health_path: NodePath = ^"HealthComponent"
@export var sprite_path: NodePath = ^"Sprite3D"
@export var agent_path: NodePath = ^"NavigationAgent3D"
## 池节点路径。留空时回退到分组查找（ObjectPool 已在 _ready 里 add_to_group）。
@export var pool_path: NodePath

@onready var _health: HealthComponent = get_node_or_null(health_path) as HealthComponent
@onready var _sprite: Sprite3D = get_node_or_null(sprite_path) as Sprite3D
@onready var _agent: NavigationAgent3D = get_node_or_null(agent_path) as NavigationAgent3D

var _state: State = State.IDLE
var _pool: ObjectPool
## 出池时用于还原的基准值。WaveSpawner 会按波次难度乘 move_speed / max_health，
## 若不复位，同一实例被复用 N 次后数值会指数膨胀（1.2 → 1.44 → 1.73 …）。
var _base_move_speed: float = 0.0
var _base_max_health: float = 0.0

## 硬直计时提到基类：State.STAGGER 是基类枚举，硬直语义本就属于基类。
## 子类（zombie.gd）只读写不声明，行数红线才喘得过气。
var _stagger_left: float = 0.0

## 击退（推挤）位移。SHOVE_TIME 内由 _shove_* 接管水平速度，
## 否则子类的 _tick_stagger 每帧 _decelerate() 会立刻吃掉击退速度。
var _shove_dir: Vector3 = Vector3.ZERO
var _shove_speed: float = 0.0
var _shove_left: float = 0.0

## 击退位移持续时长。7 m/s × 0.18s ≈ 1.26m 后退，小于 attack_range 1.6，
## 被推开的丧尸仍在追击弧内，不会一推就脱战。
const SHOVE_TIME := 0.18

## 受推挤：写入击退速度脉冲并强制进入 STAGGER，零伤害。
## from_position 只用来定方向 —— 击退永远背离推挤者，不跟玩家朝向走。
func apply_shove(from_position: Vector3, speed: float, stagger: float) -> void:
	if _state == State.DEAD:
		return
	var dir: Vector3 = global_position - from_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -global_transform.basis.z
	_shove_dir = dir.normalized()
	_shove_speed = maxf(speed, 0.0)
	_shove_left = SHOVE_TIME
	_stagger_left = maxf(_stagger_left, stagger)
	_state = State.STAGGER

## 击退位移推进。返回 true 表示本帧位移由击退接管，调用方不要再减速。
func _integrate_shove(delta: float) -> bool:
	if _shove_left <= 0.0:
		return false
	_shove_left = maxf(_shove_left - delta, 0.0)
	velocity.x = _shove_dir.x * _shove_speed
	velocity.z = _shove_dir.z * _shove_speed
	return true

func _clear_shove() -> void:
	_shove_dir = Vector3.ZERO
	_shove_speed = 0.0
	_shove_left = 0.0

## 子类 _ready() 首行调用。必须早于任何难度乘数生效。
func _capture_base_stats() -> void:
	_base_move_speed = move_speed
	_base_max_health = max_health

## 子类覆盖：复位各自的 AI 变量（目标、攻击冷却、硬直计时、命中标记等）。
func _reset_spawn_state() -> void:
	pass

## 幂等保证 Weakspot 在正确分组里。场景文件里的 groups 段容易在重新生成时丢失，
## 这里兜底，代价只有一次 is_in_group 查询。
func _ensure_weakspot_group() -> void:
	var weak: Node = get_node_or_null(^"Weakspot")
	if weak == null:
		push_warning("Zombie: 缺少 Weakspot 节点，弱点伤害将退化为普通命中。")
		return
	if not weak.is_in_group(GameLayers.GROUP_WEAKSPOT):
		weak.add_to_group(GameLayers.GROUP_WEAKSPOT)

func _resolve_pool() -> void:
	if _pool != null and is_instance_valid(_pool):
		return
	_pool = ObjectPool.resolve_for(self, pool_path)

func _return_to_pool() -> void:
	if _pool == null:
		_resolve_pool()
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()

# ── 池化回调 ────────────────────────────────────────────────────

## ObjectPool.acquire 时调用：完全复位，等价于"新生成"
func _on_pool_acquired() -> void:
	set_physics_process(true)
	_state = State.IDLE
	velocity = Vector3.ZERO
	# 先还原基准值，否则 WaveSpawner._apply_difficulty 的乘数会跨复用累积
	if _base_max_health > 0.0:
		max_health = _base_max_health
	if _base_move_speed > 0.0:
		move_speed = _base_move_speed
	if _health != null:
		_health.max_health = max_health
		_health.reset_health()
	_clear_shove()
	_reset_spawn_state()
	# 存活数由 WaveSpawner 统一广播，避免两个来源互相覆盖 Director 的输入

## ObjectPool.release 时调用：彻底静默
func _on_pool_released() -> void:
	_state = State.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)
	_clear_shove()
	_reset_spawn_state()

## 是否处于"在打"状态（池中休眠或已死亡返回 false）
func is_active_zombie() -> bool:
	return _state != State.DEAD and not is_queued_for_deletion()

## 暴露血量组件给 WaveSpawner 施加波次难度（血量乘数需在 reset 前改 max_health）
func health_node() -> HealthComponent:
	return _health

func current_state() -> State:
	return _state
