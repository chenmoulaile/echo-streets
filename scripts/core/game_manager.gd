## 主控 GameManager（Autoload）—— 游戏状态机 / 慢动作 / 击杀计数 / 关卡推进
## class_name: 无（Autoload 注册名 GameManager 已是全局标识符，再加 class_name
##           会报 "hides an autoload singleton"）
## 挂载节点类型: Node（Project Settings > Autoload，名称 GameManager，
##               路径 res://scripts/core/game_manager.gd）
## 依赖信号:
##   监听 —— EventBus.player_died / execution_slowmo / zombie_died /
##           wave_started / wave_cleared / all_waves_cleared /
##           level_objective_completed
##   发出 —— EventBus.game_state_changed / kill_count_changed
## 节点路径假设: 无硬依赖。关卡根节点通过 GameManager.bind_level() 注入引用，
##               未注入时用 group 兜底（"Player" / "WaveSpawner"）。
## 与 PDF 的对应:
##   - "处决镜头 Engine.time_scale 降至 0.25，0.4~0.6 秒后恢复" → 见 _slowmo()。
##   - "存档 JSON 序列化到 user://，每关通关节点自动存档" → save_game / load_game。
##   - "强化词条红线：禁无敌/瞬间满血/无限弹药" → 本类不提供任何 debug 回血接口，
##     heal 只经由 Player 的词条通道。
## 关键修复（相对旧骨架）:
##   旧代码 `await get_tree().create_timer(duration * SLOWMO_SCALE).timeout` ——
##   create_timer 默认受 Engine.time_scale 影响，0.25 倍速下会被二次缩放，
##   实际墙钟时长变成 duration*0.25/0.25 之外的错值。现改为 create_timer(
##   duration, true, false, true)（ignore_time_scale=true），并用守卫 token
##   防止慢动作叠加。
extends Node

const Chapters := preload("res://scripts/level/chapters.gd")
const MAIN_SCENE := "res://scenes/main.tscn"

enum GameState { BOOT, PLAYING, PAUSED, DEAD, LEVEL_COMPLETE }

const SLOWMO_SCALE: float = 0.25          ## PDF 规定值
const SLOWMO_MIN: float = 0.4             ## PDF 下限
const SLOWMO_MAX: float = 0.6             ## PDF 上限
## 存档 IO 层（JSON 读写 / 存在性检查）。路径常量随之迁移到 save_io.gd。
const SaveIO := preload("res://scripts/core/save_io.gd")

var _state: GameState = GameState.BOOT
var _kill_count: int = 0
var _level_index: int = 0
var _chapter_index: int = 0
var _slowmo_token: int = 0
var _is_slowmo_active: bool = false

## 是否有模态 UI（设置面板）正在占用输入。
## 为什么不能只靠 get_viewport().set_input_as_handled()：
##   _unhandled_input 的调用顺序由节点树决定，GameManager 是 Autoload（在场景树根下，
##   先于场景节点收到 _unhandled_input），面板来不及抢。所以必须有一个显式开关。
var ui_modal: bool = false

## 关卡引用（bind_level 注入，可为空）
var _player: Node
var _wave_spawner: WaveSpawner
var _director: Director

func _ready() -> void:
	# Autoload 必须在暂停时继续跑（PAUSED 状态要能接收输入）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 输入动作必须在本节点开始监听输入前注册，否则 _unhandled_input 里的
	# is_action_pressed(&"pause") 会因动作不存在而报错。Player 侧的调用是补强，
	# 不能作为唯一注册点（无 Player 的测试场景会缺失 pause）。
	InputSetup.ensure_defaults()
	EventBus.player_died.connect(_on_player_died)
	EventBus.execution_slowmo.connect(_on_execution_slowmo)
	EventBus.zombie_died.connect(_on_zombie_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.all_waves_cleared.connect(_on_all_waves_cleared)
	EventBus.level_objective_completed.connect(_on_level_objective_completed)

func _exit_tree() -> void:
	# Autoload 退出时还原时间缩放，避免编辑器里残留 0.25 倍速
	Engine.time_scale = 1.0

func _unhandled_input(event: InputEvent) -> void:
	# 设置面板占着输入时不要抢 ESC，否则面板刚关就被 pause_game() 接管
	if ui_modal:
		return
	if event.is_action_pressed(&"pause") and _state == GameState.PLAYING:
		pause_game()
	elif event.is_action_pressed(&"pause") and _state == GameState.PAUSED:
		resume_game()

# ── 状态机 ──────────────────────────────────────────────────────

func state() -> GameState:
	return _state

func is_playing() -> bool:
	return _state == GameState.PLAYING

## 关卡启动：绑定节点并开始第一波
func start_level(player: Node = null, spawner: WaveSpawner = null, director: Director = null) -> void:
	bind_level(player, spawner, director)
	_kill_count = 0
	EventBus.kill_count_changed.emit(_kill_count)
	_set_state(GameState.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _wave_spawner != null:
		_wave_spawner.start(_player as Node3D)
	else:
		push_warning("GameManager: 未绑定 WaveSpawner，关卡不会刷怪。")

## 注入关卡内节点引用（也可省略，由 group 兜底解析）
func bind_level(player: Node = null, spawner: WaveSpawner = null, director: Director = null) -> void:
	_player = player if player != null else get_tree().get_first_node_in_group(GameLayers.GROUP_PLAYER)
	if spawner != null:
		_wave_spawner = spawner
	else:
		var s: Node = get_tree().get_first_node_in_group(GameLayers.GROUP_WAVE_SPAWNER)
		_wave_spawner = s as WaveSpawner
	if director != null:
		_director = director
	else:
		var d: Node = get_tree().get_first_node_in_group(GameLayers.GROUP_DIRECTOR)
		_director = d as Director

func pause_game() -> void:
	if _state != GameState.PLAYING:
		return
	_set_state(GameState.PAUSED)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume_game() -> void:
	if _state != GameState.PAUSED:
		return
	_set_state(GameState.PLAYING)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## 重开本关（DEAD 状态下由 UI 调用）
func restart_level() -> void:
	_set_state(GameState.BOOT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	_is_slowmo_active = false
	_slowmo_token += 1
	if _wave_spawner != null:
		_wave_spawner.stop()
	if _player != null and _player.has_method(&"reset_player"):
		_player.call(&"reset_player")
	# reset_player 不复位 global_position（换章时位置由章节决定），
	# 所以重开必须显式把玩家搬回本章出生点。
	var level: Node = get_tree().current_scene
	if level != null and level.has_method(&"place_player_at_start"):
		level.call(&"place_player_at_start")
	start_level(_player, _wave_spawner, _director)

func _set_state(next: GameState) -> void:
	if _state == next:
		return
	_state = next
	EventBus.game_state_changed.emit(int(_state))

# ── 击杀计数 ────────────────────────────────────────────────────

func kill_count() -> int:
	return _kill_count

func _on_zombie_died(_zombie: Node, _killer: Node) -> void:
	_kill_count += 1
	EventBus.kill_count_changed.emit(_kill_count)

# ── 慢动作（处决镜头）──────────────────────────────────────────

## 请求慢动作。duration 会被钳制到 PDF 规定的 0.4~0.6 秒区间。
func _on_execution_slowmo(duration: float) -> void:
	request_slowmo(duration)

func request_slowmo(duration: float) -> void:
	if _is_slowmo_active:
		return  # 不叠加，避免多次处决把时间缩放锁死在 0.25
	var clamped: float = clampf(duration, SLOWMO_MIN, SLOWMO_MAX)
	_is_slowmo_active = true
	_slowmo_token += 1
	var token: int = _slowmo_token
	Engine.time_scale = SLOWMO_SCALE
	# 第三个参数 process_always=true 让计时器在 paused 时也走；
	# 第四个参数 ignore_time_scale=true 是修复点：不受 time_scale 二次缩放。
	var timer: SceneTreeTimer = get_tree().create_timer(clamped, true, false, true)
	await timer.timeout
	if token != _slowmo_token:
		return  # 已被 restart_level 或新的慢动作取代
	Engine.time_scale = 1.0
	_is_slowmo_active = false

func is_slowmo_active() -> bool:
	return _is_slowmo_active

# ── 关卡推进 ────────────────────────────────────────────────────

func _on_player_died() -> void:
	if _state == GameState.DEAD:
		return
	Engine.time_scale = 1.0
	_is_slowmo_active = false
	_slowmo_token += 1
	_set_state(GameState.DEAD)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_wave_started(wave_index: int, _total_count: int) -> void:
	_level_index = wave_index

func _on_all_waves_cleared() -> void:
	if _state != GameState.PLAYING:
		return
	# 本章所有波次打完：有下一章就换章，没有才判定 demo 通关。
	if has_next_chapter():
		advance_chapter()
	else:
		complete_level()

# ── 章节推进 ────────────────────────────────────────────────────

## 当前章节序号（关卡根节点在 _ready 里读它决定构建哪一章）
func chapter_index() -> int:
	return _chapter_index

func chapter_total() -> int:
	return Chapters.count()

func has_next_chapter() -> bool:
	return _chapter_index + 1 < Chapters.count()

## 直接跳到指定章（调试 / 章节选择用）。只改序号，实际重建由调用方触发。
func set_chapter(index: int) -> void:
	_chapter_index = clampi(index, 0, maxi(Chapters.count() - 1, 0))

## 进入下一章：重建主场景。几何/天空/刷怪点/波次全部由 Level._ready 按新章重算，
## Player 也是场景里的新实例，因此血量与弹药自动回到初始值。
## 必须先把 paused / time_scale 复位，否则新场景一进来就是暂停或 0.25 倍速。
func advance_chapter() -> void:
	if not has_next_chapter():
		complete_level()
		return
	_chapter_index += 1
	get_tree().paused = false
	Engine.time_scale = 1.0
	_is_slowmo_active = false
	_slowmo_token += 1
	EventBus.chapter_advanced.emit(_chapter_index)
	var err: int = get_tree().reload_current_scene()
	if err != OK:
		push_error("GameManager: 章节 %d 重建场景失败 err=%d" % [_chapter_index, err])

## 从第一章重新开始整个 demo（通关后或章节选择用）
func restart_demo() -> void:
	_chapter_index = 0
	get_tree().paused = false
	Engine.time_scale = 1.0
	_is_slowmo_active = false
	_slowmo_token += 1
	var err: int = get_tree().reload_current_scene()
	if err != OK:
		push_error("GameManager: 重开 demo 失败 err=%d" % err)

## 通关：切状态并自动存档（PDF：每关通关节点自动存档）
func complete_level() -> void:
	_set_state(GameState.LEVEL_COMPLETE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	save_game()

func _on_level_objective_completed() -> void:
	# 推进型关卡（非守点）用目标完成信号触发通关
	if _state == GameState.PLAYING:
		complete_level()

# ── 存档（PDF：JSON 序列化到 user://）────────────────────────────

func save_game() -> bool:
	var payload: Dictionary = {
		"version": 2,
		"chapter_index": _chapter_index,
		"chapter_total": Chapters.count(),
		"level_index": _level_index,
		"kill_count": _kill_count,
		"player_health": _player_health(),
		"saved_at": Time.get_datetime_string_from_system(),
	}
	return SaveIO.write(payload)

## 读取存档。文件不存在或 JSON 损坏时返回空字典，不抛异常。
func load_game() -> Dictionary:
	return SaveIO.read()

func has_save() -> bool:
	return SaveIO.exists()

func _player_health() -> float:
	if _player == null or not _player.has_method(&"is_alive"):
		return 0.0
	var health: Node = _player.get_node_or_null(^"HealthComponent")
	if health is HealthComponent:
		return (health as HealthComponent).current_health()
	return 0.0
