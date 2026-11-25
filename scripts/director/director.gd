## 导演系统（Director）—— 全局压力值驱动的动态难度
## class_name: Director
## 挂载节点类型: Node（建议挂在关卡根节点下，与 WaveSpawner 平级）
## 依赖信号:
##   监听 —— EventBus.player_health_changed / player_hit / ammo_changed /
##           zombie_count_changed / wave_started / wave_cleared
##   发出 —— EventBus.director_pressure_changed
## 节点路径假设:
##   - @export wave_spawner_path 指向同场景的 WaveSpawner（可为空，空则只发压力值
##     不做刷怪节流，供 HUD / 音频单独消费）。
##   - @export player_path 指向 Player（可为空，空则用 group "Player" 兜底）。
## 与 PDF 的对应（原文）:
##   "导演系统维护全局压力值，输入包括玩家生命、弹药存量、最近受击间隔、
##    视野内敌人密度，输出刷怪间隔与特感投放权重。"
## 实现要点:
##   1. 压力值 pressure ∈ [0,1]。四路输入各归一化后加权求和。
##   2. 压力高 → 刷怪间隔变长（给玩家喘息）、特感权重降低；压力低 → 加压。
##      这是"动态难度"的正确方向：玩家越惨，系统越松。
##   3. 用指数平滑（lerp）避免压力值抖动导致刷怪节奏抽搐。
class_name Director
extends Node

@export_group("输入权重")
## 玩家生命权重（血越少压力越高）
@export var weight_health: float = 0.35
## 弹药存量权重（弹越少压力越高）
@export var weight_ammo: float = 0.25
## 最近受击间隔权重（刚被打压力高）
@export var weight_recent_hit: float = 0.20
## 视野内敌人密度权重（敌人越多压力越高）
@export var weight_density: float = 0.20

@export_group("调参")
## 压力值平滑系数（每秒逼近速度）。越大越灵敏。
@export var smoothing: float = 1.5
## 受击后视为"高压"的衰减时长（秒）
@export var recent_hit_window: float = 4.0
## 视野内敌人数达到该值时密度输入饱和
@export var density_saturation: float = 20.0
## 弹药视为"见底"的阈值（弹匣+备弹合计）
@export var low_ammo_threshold: int = 12

@export_group("输出映射")
## 压力 0 时的刷怪间隔乘数（更快刷怪 = 更凶）
@export var interval_mult_at_min: float = 1.15
## 压力 1 时的刷怪间隔乘数（更慢刷怪 = 更松）
@export var interval_mult_at_max: float = 1.8
## 压力 0 时的特感比例加成
@export var special_bonus_at_min: float = 0.10
## 压力 1 时的特感比例加成
@export var special_bonus_at_max: float = -0.05

@export_group("节点路径")
@export var wave_spawner_path: NodePath
@export var player_path: NodePath

var _pressure: float = 0.5
var _target_pressure: float = 0.5
var _since_last_hit: float = 999.0
var _player: Node
var _spawner: WaveSpawner

# 缓存的输入原始值
var _health_ratio: float = 1.0
var _ammo_total: int = 999
var _alive_zombies: int = 0

func _ready() -> void:
	add_to_group(GameLayers.GROUP_DIRECTOR)
	_resolve_nodes()
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.zombie_count_changed.connect(_on_zombie_count_changed)
	EventBus.wave_started.connect(_on_wave_started)

func _exit_tree() -> void:
	if EventBus.player_health_changed.is_connected(_on_health_changed):
		EventBus.player_health_changed.disconnect(_on_health_changed)
	if EventBus.player_hit.is_connected(_on_player_hit):
		EventBus.player_hit.disconnect(_on_player_hit)
	if EventBus.ammo_changed.is_connected(_on_ammo_changed):
		EventBus.ammo_changed.disconnect(_on_ammo_changed)
	if EventBus.zombie_count_changed.is_connected(_on_zombie_count_changed):
		EventBus.zombie_count_changed.disconnect(_on_zombie_count_changed)
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)

func _process(delta: float) -> void:
	_since_last_hit += delta
	_target_pressure = _compute_pressure()
	# 指数平滑：帧率无关的 lerp
	var t: float = 1.0 - exp(-smoothing * delta)
	var prev: float = _pressure
	_pressure = lerpf(_pressure, _target_pressure, t)
	if absf(_pressure - prev) > 0.001:
		EventBus.director_pressure_changed.emit(_pressure)
	_apply_output()

# ── 查询 ────────────────────────────────────────────────────────

## 当前平滑后的压力值 0.0~1.0
func pressure() -> float:
	return _pressure

## 未平滑的目标压力值（四路输入即时加权结果）。调试与单测用。
func target_pressure() -> float:
	return _target_pressure

## 压力对应的一档文字描述（HUD / 调试用）
func pressure_label() -> String:
	if _pressure < 0.3:
		return "松弛"
	if _pressure < 0.6:
		return "警戒"
	if _pressure < 0.85:
		return "高压"
	return "濒临崩溃"

# ── 输入 ────────────────────────────────────────────────────────

func _compute_pressure() -> float:
	var health_in: float = clampf(1.0 - _health_ratio, 0.0, 1.0)
	var ammo_in: float = _ammo_pressure()
	var hit_in: float = clampf(1.0 - _since_last_hit / maxf(recent_hit_window, 0.01), 0.0, 1.0)
	var density_in: float = clampf(float(_alive_zombies) / maxf(density_saturation, 1.0), 0.0, 1.0)
	var total_weight: float = weight_health + weight_ammo + weight_recent_hit + weight_density
	if total_weight <= 0.0:
		return 0.5
	var sum: float = health_in * weight_health + ammo_in * weight_ammo \
		+ hit_in * weight_recent_hit + density_in * weight_density
	return clampf(sum / total_weight, 0.0, 1.0)

## 弹药压力：总量低于阈值时按比例上升
func _ammo_pressure() -> float:
	if _ammo_total >= low_ammo_threshold:
		return 0.0
	return clampf(1.0 - float(_ammo_total) / maxf(float(low_ammo_threshold), 1.0), 0.0, 1.0)

func _on_health_changed(current: float, max_value: float) -> void:
	_health_ratio = clampf(current / maxf(max_value, 1.0), 0.0, 1.0)

func _on_player_hit(_damage: float, _source: Node) -> void:
	_since_last_hit = 0.0

func _on_ammo_changed(mag_ammo: int, reserve_ammo: int) -> void:
	_ammo_total = mag_ammo + reserve_ammo

func _on_zombie_count_changed(alive: int) -> void:
	_alive_zombies = alive

func _on_wave_started(_wave_index: int, _total_count: int) -> void:
	# 新波开始重置受击计时，避免上一波残留的高压拖慢本波节奏
	_since_last_hit = maxf(_since_last_hit, recent_hit_window)

# ── 输出 ────────────────────────────────────────────────────────

## 把压力映射成刷怪间隔乘数与特感比例加成，写回 WaveSpawner。
## 每帧调用，但只在数值变化超过阈值时才写（避免每帧 dirty）。
func _apply_output() -> void:
	if _spawner == null or not is_instance_valid(_spawner):
		return
	var interval_mult: float = lerpf(interval_mult_at_min, interval_mult_at_max, _pressure)
	var special_bonus: float = lerpf(special_bonus_at_min, special_bonus_at_max, _pressure)
	_spawner.apply_director_output(interval_mult, special_bonus)

# ── 节点解析 ────────────────────────────────────────────────────

func _resolve_nodes() -> void:
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	if _player == null:
		_player = get_tree().get_first_node_in_group(GameLayers.GROUP_PLAYER)
	if not wave_spawner_path.is_empty():
		_spawner = get_node_or_null(wave_spawner_path) as WaveSpawner
	if _spawner == null:
		var found: Node = get_tree().get_first_node_in_group(GameLayers.GROUP_WAVE_SPAWNER)
		_spawner = found as WaveSpawner
	if _spawner == null:
		push_warning("Director: 未找到 WaveSpawner，仅广播压力值不做刷怪节流。")
