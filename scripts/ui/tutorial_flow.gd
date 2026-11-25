## 新手教程推进器：按「玩家真的做了这个动作」推进，而不是干等计时。
## class_name: TutorialFlow
## 挂载节点类型: Node（挂在 main.tscn 的 Main 下，与 Hud 同级）
## 依赖信号:
##   监听 —— EventBus.chapter_started（决定要不要开教程）/ player_fired /
##           reload_started / ads_changed / player_shoved / weapon_switched /
##           settings_changed
##   发出 —— EventBus.tutorial_step（Hud 显示文案）
##
## 为什么不是纯定时序列:
##   纯定时的话，玩家一开局就开枪，第一屏还在教 WASD —— 提示与行为错位，
##   读起来像 BUG。改成「动作触发 + 超时兜底」：做了就立刻跳到下一条，
##   没做就等够 STEP_TIMEOUT 再往下走，不会把新手卡在某一步。
##
## 为什么只在第一章跑:
##   换章会 reload 场景，本节点会重建。教程每章重播一遍会变成噪音，
##   而第一章之外玩家已经会了。判据是 GameManager.chapter_index() == 0。
extends Node

## 单步最长等待（秒）。够玩家读完一行再动手，又不至于让站着不动的人卡死。
const STEP_TIMEOUT := 9.0
## 开局到第一条提示的延迟。章节横幅占 3.2 秒，提示要在横幅淡出前不抢视线，
## 但又不能等太久 —— 1.6 秒时横幅已稳定，提示从下方淡入不重叠。
const FIRST_DELAY := 1.6
## 移动判定阈值（米/秒）。低于这个值算抖动，不算"走了"。
const MOVE_EPSILON := 0.6

var _order: Array[int] = []
var _index: int = -1
var _left: float = 0.0
var _armed: bool = false
var _started: bool = false
var _player: Node3D

func _ready() -> void:
	_order = [
		Tutorial.Step.MOVE,
		Tutorial.Step.FIRE,
		Tutorial.Step.RELOAD,
		Tutorial.Step.AIM,
		Tutorial.Step.SHOVE,
		Tutorial.Step.SWAP,
		Tutorial.Step.SETTINGS,
		Tutorial.Step.ROUTE,
	]
	EventBus.chapter_started.connect(_on_chapter_started)
	EventBus.player_fired.connect(_on_player_fired)
	EventBus.reload_started.connect(_on_reload_started)
	EventBus.ads_changed.connect(_on_ads_changed)
	EventBus.player_shoved.connect(_on_player_shoved)
	EventBus.weapon_switched.connect(_on_weapon_switched)
	EventBus.settings_changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	var pairs: Array = [
		[EventBus.chapter_started, _on_chapter_started],
		[EventBus.player_fired, _on_player_fired],
		[EventBus.reload_started, _on_reload_started],
		[EventBus.ads_changed, _on_ads_changed],
		[EventBus.player_shoved, _on_player_shoved],
		[EventBus.weapon_switched, _on_weapon_switched],
		[EventBus.settings_changed, _on_settings_changed],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

# ── 启动 ────────────────────────────────────────────────────────

## 只在第一章、且本实例还没跑过时启动。
## chapter_started 由关卡在 _load_chapter 末尾发出，那时 Hud 已接线（Hud 的 _ready 更早），
## 所以这里发的第一条提示不会丢。
func _on_chapter_started(index: int, _total: int, _title: String, _objective: String) -> void:
	if _started or index != 0:
		return
	_started = true
	_player = get_tree().get_first_node_in_group(GameLayers.GROUP_PLAYER) as Node3D
	_index = -1
	_armed = false
	_left = FIRST_DELAY

func _process(delta: float) -> void:
	if not _started:
		return
	if not _armed:
		_left -= delta
		if _left <= 0.0:
			_armed = true
			_index = 0
			_left = STEP_TIMEOUT
			_emit_current()
		return
	# MOVE 没有信号可挂，只能看速度
	if _current() == Tutorial.Step.MOVE and _player_moving():
		_advance()
		return
	_left -= delta
	if _left <= 0.0:
		_advance()

func _current() -> int:
	if _index < 0 or _index >= _order.size():
		return -1
	return _order[_index]

func _emit_current() -> void:
	var step: int = _current()
	if step < 0:
		return
	EventBus.tutorial_step.emit(step)

func _advance() -> void:
	_index += 1
	if _index >= _order.size():
		_armed = false
		_started = false
		EventBus.tutorial_step.emit(-1)
		return
	_left = STEP_TIMEOUT
	_emit_current()

func _player_moving() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(GameLayers.GROUP_PLAYER) as Node3D
		if _player == null:
			return false
	var v: Vector3 = _player.velocity
	return Vector2(v.x, v.z).length() > MOVE_EPSILON

# ── 动作触发 ────────────────────────────────────────────────────

func _on_player_fired(_data: Resource, _recoil: float) -> void:
	_consume(Tutorial.Step.FIRE)

func _on_reload_started(_duration: float) -> void:
	_consume(Tutorial.Step.RELOAD)

func _on_ads_changed(aiming: bool) -> void:
	if aiming:
		_consume(Tutorial.Step.AIM)

func _on_player_shoved(_hits: int) -> void:
	_consume(Tutorial.Step.SHOVE)

## 切枪也算"换武器"。第一步的 _equip(0, true) 会在本节点接线前发，
## 所以不会误判成玩家切过枪。
func _on_weapon_switched(_data: Resource, _slot: int) -> void:
	_consume(Tutorial.Step.SWAP)

func _on_settings_changed() -> void:
	_consume(Tutorial.Step.SETTINGS)

## 只有「当前步正好是这个动作」才推进。提前做的动作不记账 ——
## 否则玩家开局连按几下 R，后面的换弹提示会被静默跳过。
func _consume(step: int) -> void:
	if not _armed:
		return
	if _current() != step:
		return
	_advance()
