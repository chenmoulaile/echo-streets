## 关卡根节点：按章构建几何 / 天空 / 刷怪点 / 波次，把 Player 交给 GameManager，并处理死亡重开。
## class_name: 无（每个关卡是独立场景，不需要类名）
## 挂载节点类型: Node3D（main.tscn 的根节点）
## 依赖信号: EventBus.chapter_started（本节点发出）/ EventBus.player_died（经 GameManager）
## 节点路径假设:
##   Main                 (Node3D, 本脚本)
##   ├── World            (Node3D, 章节几何 + 天空，运行时由 ChapterBuilder 填充)
##   ├── Player           (player.tscn)
##   ├── WaveSpawner      (wave_spawner.tscn，SpawnPoints 子节点运行时重建)
##   ├── Director         (director.tscn)
##   ├── PostFX           (CanvasLayer，像素化后期，post 参数按章覆盖)
##   └── Hud              (CanvasLayer，像素 HUD)
## 存在理由: GameManager 是 Autoload，不持有场景引用；必须由关卡在 _ready 里
##           显式注入，否则 GameManager 只能用 group 兜底且拿不到 waves 配置。
## 为什么几何在运行时构建而不是写进 main.tscn:
##   四章几何各有 100+ 条原语，全部烘焙进 .tscn 会让主场景膨胀到无法审阅，
##   而且顶点色光照依赖构建期的 lamp 列表，只能由 ChapterBuilder 现场算。
##   代价是换章必须重建场景（见 GameManager.advance_chapter）。
extends Node3D

const ChapterBuilder := preload("res://scripts/level/chapter_builder.gd")
const Chapters := preload("res://scripts/level/chapters.gd")
const ZOMBIE_DIR := "res://scenes/"
## 特感权重固定 charger/bomber/screamer，与 data/wave_*.tres 的既有配比一致
const SPECIAL_WEIGHTS: Array[float] = [0.45, 0.3, 0.25]
const SPECIAL_SCENES: Array[String] = [
	"zombie_charger", "zombie_bomber", "zombie_screamer",
]

@export var player_path: NodePath = ^"Player"
@export var spawner_path: NodePath = ^"WaveSpawner"
@export var director_path: NodePath = ^"Director"
@export var world_path: NodePath = ^"World"
@export var postfx_path: NodePath = ^"PostFX"
## 死亡后按哪个键重开（与 HUD 文案 "PRESS R TO RETRY" 对应）
@export var retry_action: StringName = &"reload"

var _player: Node
var _spawner: WaveSpawner
var _director: Director
var _world: Node3D
var _postfx: CanvasLayer
var _data: ChapterData

## _enter_tree 早于所有子节点的 _ready 执行。WaveSpawner._ready 会检查 waves 是否为空，
## 空则生成占位波次并 push_warning —— 所以真实波次必须在这里塞进去，
## 否则每次开局都会刷一条 "waves 为空" 的假警告，掩盖真正的配置问题。
func _enter_tree() -> void:
	_spawner = get_node_or_null(spawner_path) as WaveSpawner
	if _spawner == null:
		return
	_data = Chapters.load_chapter(GameManager.chapter_index())
	if _data == null:
		push_error("Level: 章节 %d 加载失败。" % GameManager.chapter_index())
		return
	_spawner.set(&"waves", _make_waves(_data))

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_spawner = get_node_or_null(spawner_path) as WaveSpawner
	_director = get_node_or_null(director_path) as Director
	_world = get_node_or_null(world_path) as Node3D
	_postfx = get_node_or_null(postfx_path) as CanvasLayer
	if _player == null:
		push_error("Level: player_path 未解析到节点，关卡无法开始。")
		return
	_load_chapter(GameManager.chapter_index())
	# 等一帧：Player/Weapon 的 _ready 与 Autoload 的信号连接全部完成后再启动，
	# 否则首帧的 weapon_switched / ammo_changed 会打到还没接线的 HUD 上。
	await get_tree().process_frame
	GameManager.start_level(_player, _spawner, _director)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(retry_action):
		return
	match GameManager.state():
		GameManager.GameState.DEAD:
			GameManager.restart_level()
		GameManager.GameState.LEVEL_COMPLETE:
			# demo 打完后 R 回到第一章（中间章不会进 LEVEL_COMPLETE，
			# 那是由 GameManager 直接 reload 换章）
			GameManager.restart_demo()
		_:
			pass

# ── 章节构建 ────────────────────────────────────────────────────

## 构建指定章节。index 越界时由 Chapters.script_path 钳到最后一章。
func _load_chapter(index: int) -> void:
	_data = Chapters.load_chapter(index)
	if _data == null:
		push_error("Level: 章节 %d 加载失败。" % index)
		return
	for issue: String in _data.validate():
		push_error("Level: [%s] %s" % [_data.id, issue])
	if _world != null:
		_clear_children(_world)
		ChapterBuilder.build(_data, _world)
		ChapterBuilder.build_sky(_data, _world)
	if _spawner != null:
		# 必须复用已存在的 SpawnPoints：WaveSpawner 在 _ready 里 @onready 缓存了
		# _spawn_points_root，整节点换掉会让引用悬空，刷怪点全部退化成环形兜底。
		var holder := _spawner.get_node_or_null(^"SpawnPoints") as Node3D
		if holder == null:
			ChapterBuilder.build_spawns(_data, _spawner)
		else:
			ChapterBuilder.fill_spawns(_data, holder)
		_spawner.set(&"waves", _make_waves(_data))
	_apply_post(_data.post)
	place_player_at_start()
	EventBus.chapter_started.emit(index, Chapters.count(), _data.title, _data.objective)

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.free()

## 章节波次 → WaveConfig 资源。fodder 固定，特感按 SPECIAL_WEIGHTS 加权抽取。
func _make_waves(data: ChapterData) -> Array[WaveConfig]:
	var out: Array[WaveConfig] = []
	var fodder: PackedScene = load(ZOMBIE_DIR + "zombie_fodder.tscn") as PackedScene
	if fodder == null:
		push_error("Level: 找不到 zombie_fodder.tscn，波次无法生成。")
		return out
	var specials: Array[PackedScene] = []
	for zname: String in SPECIAL_SCENES:
		var ps: PackedScene = load(ZOMBIE_DIR + zname + ".tscn") as PackedScene
		if ps != null:
			specials.append(ps)
	for w: Dictionary in data.waves:
		var cfg := WaveConfig.new()
		cfg.total_count = int(w.get("total", 12))
		cfg.max_alive = int(w.get("max_alive", 24))
		cfg.spawn_interval = float(w.get("interval", 0.8))
		cfg.prepare_time = float(w.get("prepare", 2.5))
		cfg.rest_time = float(w.get("rest", 4.0))
		cfg.special_ratio = float(w.get("special_ratio", 0.0))
		cfg.speed_multiplier = float(w.get("speed", 1.0))
		cfg.health_multiplier = float(w.get("health", 1.0))
		cfg.fodder_scene = fodder
		cfg.special_scenes = specials.duplicate()
		cfg.special_weights = SPECIAL_WEIGHTS.duplicate()
		out.append(cfg)
	return out

## 按章覆盖后期参数（只写 data.post 里出现的键，其余保持 main.tscn 的值）
func _apply_post(overrides: Dictionary) -> void:
	if _postfx == null or overrides.is_empty():
		return
	var rect := _postfx.get_node_or_null(^"PixelPost") as ColorRect
	if rect == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		return
	for key: String in overrides:
		mat.set_shader_parameter(StringName(key), overrides[key])

# ── 玩家落位 ────────────────────────────────────────────────────

## 把玩家搬到本章出生点并朝向指定方位。重开本关时由 GameManager 再次调用。
## 只写 global_position / rotation.y —— Player 的 pitch 由 reset_player 负责复位。
func place_player_at_start() -> void:
	if _player == null or _data == null:
		return
	var body := _player as Node3D
	if body == null:
		return
	body.global_position = _data.player_start
	body.rotation.y = deg_to_rad(_data.player_yaw)

## 供 HUD / 调试读取当前章信息
func chapter_data() -> ChapterData:
	return _data
