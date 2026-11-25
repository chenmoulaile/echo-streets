## 波次生成器（按 WaveConfig 编排刷怪 / 池化复用 / 波次推进）
## class_name: WaveSpawner
## 挂载节点类型: Node3D（需要 transform 作为刷怪点父级参考）
## 依赖信号:
##   监听 —— EventBus.zombie_died（统计本波剩余）
##   发出 —— EventBus.wave_started / wave_cleared / all_waves_cleared /
##           zombie_count_changed
## 节点路径假设（场景树结构）:
##   WaveSpawner            (Node3D, 本脚本, group "WaveSpawner")
##   ├── SpawnPoints        (Node3D)
##   │   ├── Point01        (Marker3D)   ← 每个子节点即一个候选刷怪点
##   │   ├── Point02        (Marker3D)
##   │   └── ...
##   └── Pools              (Node3D)     ← 运行时在此挂载每种敌人的 ObjectPool
## 与 PDF 的对应:
##   - "丧尸全部对象池化，目标同屏 60 只稳定 60 帧" → 每种敌人一个 ObjectPool，
##     预分配 24，上限 64，超出则跳过本次刷怪而不是卡帧扩容。
##   - "导演系统输出刷怪间隔" → @export spawn_interval 可被 Director 运行时覆盖。
## 关键修复（相对旧骨架）:
##   1. 旧代码内部 class WaveConfig 无 class_name → 跨文件 Array[WaveConfig]
##      类型无法解析。已拆到 scripts/director/wave_config.gd。
##   2. 旧代码 `get_node(pool_path) if pool_path else null` 对空 NodePath 判断
##      语义脆弱 → 改为 is_empty() 显式判定 + 运行时自建池。
class_name WaveSpawner
extends Node3D

## 本波阶段
enum Phase { IDLE, PREPARE, SPAWNING, WAITING_CLEAR, REST, FINISHED }

@export_group("波次编排")
## 按顺序执行的波次列表。为空时用 fallback_waves 自动生成。
@export var waves: Array[WaveConfig] = []
## 波次列表为空时自动生成的波数
@export var fallback_wave_count: int = 5
## 自动生成时每波数量递增
@export var fallback_base_count: int = 8
@export var fallback_growth: int = 4

@export_group("池化")
@export var pool_initial_size: int = 24
@export var pool_max_size: int = 64

@export_group("刷怪点")
## 刷怪点父节点。其 Marker3D / Node3D 子节点即候选点。
@export var spawn_points_path: NodePath = ^"SpawnPoints"
## 池容器节点。留空时池直接挂在本节点下。
@export var pools_path: NodePath = ^"Pools"
## 刷怪点距玩家最小距离（太近会糊脸，破坏体验）
@export var min_player_distance: float = 8.0

@onready var _spawn_points_root: Node3D = get_node_or_null(spawn_points_path) as Node3D
@onready var _pools_root: Node3D = get_node_or_null(pools_path) as Node3D

var _phase: Phase = Phase.IDLE
var _wave_index: int = -1
var _queue: Array[PackedScene] = []       ## 本波待刷队列
var _spawned_total: int = 0               ## 本波已刷出总数
var _alive: int = 0                       ## 当前存活（含本波与历史残留）
var _timer: float = 0.0
var _pools: Dictionary = {}               ## PackedScene -> ObjectPool
var _player: Node3D
var _rng := RandomNumberGenerator.new()
## Director 写入的运行时调参（默认 1.0 / 0.0 = 无干预）
var _director_interval: float = 1.0
var _director_special: float = 0.0

func _ready() -> void:
	add_to_group(GameLayers.GROUP_WAVE_SPAWNER)
	_rng.randomize()
	if _pools_root == null:
		_pools_root = self
	EventBus.zombie_died.connect(_on_zombie_died)
	_ensure_waves()

func _exit_tree() -> void:
	if EventBus.zombie_died.is_connected(_on_zombie_died):
		EventBus.zombie_died.disconnect(_on_zombie_died)

func _process(delta: float) -> void:
	match _phase:
		Phase.PREPARE, Phase.REST:
			_timer -= delta
			if _timer <= 0.0:
				_begin_wave()
		Phase.SPAWNING:
			_tick_spawn(delta)
		Phase.WAITING_CLEAR:
			pass  # 由 zombie_died 推进

# ── 对外控制 ────────────────────────────────────────────────────

## 启动整轮波次。player 用于刷怪点距离过滤。
func start(player: Node3D = null) -> void:
	_player = player
	if _player == null:
		var found: Node = get_tree().get_first_node_in_group(GameLayers.GROUP_PLAYER)
		_player = found as Node3D
	_wave_index = -1
	_phase = Phase.REST
	_timer = 0.0

## 立即停止并清空（玩家死亡 / 关卡重置）
func stop() -> void:
	_phase = Phase.IDLE
	_queue.clear()
	_spawned_total = 0
	for pool: ObjectPool in _pools.values():
		pool.release_all()
	_alive = 0
	EventBus.zombie_count_changed.emit(0)

## 当前波序号（0 起，未开始为 -1）
func current_wave() -> int:
	return _wave_index

func current_phase() -> Phase:
	return _phase

func total_waves() -> int:
	return waves.size()

## 供 Director 每帧写入动态难度输出。参数已由 Director 归一化好，这里只做钳制。
func apply_director_output(interval_multiplier: float, special_ratio_bonus: float) -> void:
	_director_interval = clampf(interval_multiplier, 0.25, 4.0)
	_director_special = clampf(special_ratio_bonus, -0.5, 0.5)

# ── 波次流程 ────────────────────────────────────────────────────

func _ensure_waves() -> void:
	if not waves.is_empty():
		_validate_waves()
		return
	# 未配置时生成一条递增曲线，保证开箱即可跑
	for i: int in fallback_wave_count:
		var cfg := WaveConfig.new()
		cfg.total_count = fallback_base_count + fallback_growth * i
		cfg.max_alive = mini(pool_initial_size, cfg.total_count)
		cfg.spawn_interval = maxf(0.9 - 0.1 * i, 0.3)
		cfg.prepare_time = 3.0
		cfg.rest_time = 4.0
		waves.append(cfg)
	push_warning("WaveSpawner: waves 为空，已自动生成 %d 波占位配置（fodder_scene 仍需赋值）。"
		% waves.size())

func _validate_waves() -> void:
	for i: int in waves.size():
		var cfg: WaveConfig = waves[i]
		if cfg == null:
			push_error("WaveSpawner: waves[%d] 为 null。" % i)
			continue
		for issue: String in cfg.validate():
			push_error("WaveSpawner: waves[%d] 配置问题: %s" % [i, issue])

func _begin_wave() -> void:
	_wave_index += 1
	if _wave_index >= waves.size():
		_phase = Phase.FINISHED
		EventBus.all_waves_cleared.emit()
		return
	var cfg: WaveConfig = waves[_wave_index]
	_build_queue(cfg)
	_spawned_total = 0
	_phase = Phase.SPAWNING
	_timer = 0.0
	EventBus.wave_started.emit(_wave_index, cfg.total_count)

## 按 special_ratio 把杂鱼与特感混入队列，再打乱顺序
func _build_queue(cfg: WaveConfig) -> void:
	_queue.clear()
	if cfg.fodder_scene == null:
		push_error("WaveSpawner: 波次 %d 缺少 fodder_scene。" % _wave_index)
		return
	var special_count: int = int(round(float(cfg.total_count) * clampf(cfg.special_ratio + _director_special, 0.0, 1.0)))
	special_count = mini(special_count, cfg.total_count)
	for _i: int in (cfg.total_count - special_count):
		_queue.append(cfg.fodder_scene)
	for _i: int in special_count:
		var special: PackedScene = cfg.pick_special()
		_queue.append(special if special != null else cfg.fodder_scene)
	# Fisher-Yates 洗牌：让特感随机散布在波次中段
	for i: int in range(_queue.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: PackedScene = _queue[i]
		_queue[i] = _queue[j]
		_queue[j] = tmp

func _tick_spawn(delta: float) -> void:
	if _queue.is_empty():
		_phase = Phase.WAITING_CLEAR
		_check_cleared()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var cfg: WaveConfig = waves[_wave_index]
	# 同屏上限：达到就等下一帧，不扩容（保帧率优先）
	if _alive >= cfg.max_alive:
		_timer = 0.15
		return
	_spawn_next(cfg)
	# Director 压力输出作用于刷怪间隔：高压时乘数 > 1 → 拉长间隔给玩家喘息
	_timer = maxf(cfg.spawn_interval * _director_interval, 0.02)

func _spawn_next(cfg: WaveConfig) -> void:
	var scene: PackedScene = _queue.pop_back()
	if scene == null:
		return
	var pool: ObjectPool = _get_pool(scene)
	if pool == null:
		return
	var zombie: Node = pool.acquire()
	if zombie == null:
		return  # 池满，丢弃本次（队列已出队，等价于跳过）
	var pos: Vector3 = _pick_spawn_position()
	var z3d: Node3D = zombie as Node3D
	if z3d != null:
		z3d.global_position = pos
		# 面向场地中心（玩家大致所在），避免生成即背对
		if _player != null:
			var flat: Vector3 = _player.global_position - pos
			flat.y = 0.0
			if flat.length_squared() > 0.01:
				z3d.rotation.y = atan2(-flat.x, -flat.z)
	_apply_difficulty(zombie, cfg)
	_spawned_total += 1
	_alive += 1
	EventBus.zombie_count_changed.emit(_alive)

## 难度曲线：波次乘数在出池后立刻施加（Zombie 的 _on_pool_acquired 已复位基础值）
func _apply_difficulty(zombie: Node, cfg: WaveConfig) -> void:
	var z: Zombie = zombie as Zombie
	if z == null:
		return
	z.move_speed *= maxf(cfg.speed_multiplier, 0.1)
	z.max_health *= maxf(cfg.health_multiplier, 0.1)
	if z.health_node() != null:
		var hp: HealthComponent = z.health_node()
		hp.max_health = z.max_health
		hp.reset_health()

func _on_zombie_died(_zombie: Node, _killer: Node) -> void:
	_alive = maxi(_alive - 1, 0)
	EventBus.zombie_count_changed.emit(_alive)
	if _phase == Phase.WAITING_CLEAR:
		_check_cleared()

func _check_cleared() -> void:
	if _phase != Phase.WAITING_CLEAR:
		return
	if _alive > 0 or not _queue.is_empty():
		return
	EventBus.wave_cleared.emit(_wave_index)
	if _wave_index + 1 >= waves.size():
		_phase = Phase.FINISHED
		EventBus.all_waves_cleared.emit()
		return
	_phase = Phase.REST
	_timer = maxf(waves[_wave_index].rest_time, 0.0)

# ── 池与刷怪点 ──────────────────────────────────────────────────

func _get_pool(scene: PackedScene) -> ObjectPool:
	var cached: ObjectPool = _pools.get(scene) as ObjectPool
	if cached != null and is_instance_valid(cached):
		return cached
	var pool := ObjectPool.new()
	pool.name = "Pool_%s" % scene.resource_path.get_file().get_basename()
	pool.scene = scene
	pool.initial_size = pool_initial_size
	pool.max_size = pool_max_size
	pool.auto_expand = true
	_pools_root.add_child(pool)
	_pools[scene] = pool
	return pool

func _pick_spawn_position() -> Vector3:
	var candidates: Array[Vector3] = []
	if _spawn_points_root != null:
		for child: Node in _spawn_points_root.get_children():
			var marker: Node3D = child as Node3D
			if marker == null or not marker.visible:
				continue
			if _player != null and marker.global_position.distance_to(_player.global_position) < min_player_distance:
				continue
			candidates.append(marker.global_position)
	if candidates.is_empty():
		# 无可用刷怪点时在自身周围环形兜底，保证波次不会卡死
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(10.0, 16.0)
		return global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	return candidates[_rng.randi_range(0, candidates.size() - 1)]
