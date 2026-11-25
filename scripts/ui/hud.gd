## 像素 HUD 总装层：状态文字（章节 / 波次 / 击杀 / 威胁 / 死亡提示）+ EventBus 接线，
## 具体读数部件（血量 / 弹药 / 准星 / 命中反馈 / 枪械贴图 / 枪口火光）委托给
## scripts/ui/hud_widgets.gd，准星与命中反馈再各自拆一个文件。
## class_name: Hud
## 挂载节点类型: CanvasLayer（放在 main.tscn 的 UI 层，独立于 3D 世界）
## 依赖信号: EventBus.player_health_changed / ammo_changed / reload_started /
##           reload_cancelled / reload_finished / weapon_switched / player_fired /
##           player_dry_fire / player_hit / zombie_hit / kill_count_changed /
##           wave_started / zombie_count_changed / director_pressure_changed /
##           game_state_changed / chapter_started / ads_changed / tutorial_step
## 节点路径假设: 无。所有子节点在 _build_ui() 里用代码创建 —— 手写大型 .tscn 的
##               格式风险高于收益，且 HUD 需要按 480x270 逻辑分辨率精确摆放。
##
## 排版口径（用户 m11566：高级、简洁）：
##   四角分区，互不重叠 —— 左上=进度块，上中=威胁，右上=弹药，左下=血量。
##   每块内部只允许一条主线（字号最大的那行）+ 一条辅助线，不叠第二层框。
##   所有分块靠**留白**分离，不画分隔框 —— 480x270 上加框就是在画面里凿洞。
class_name Hud
extends CanvasLayer

const LOGICAL_SIZE := Vector2(480.0, 270.0)
## 章节横幅停留时长。低于 1.5 秒读不完副标题，高于 4 秒会压住第一波的视野。
const BANNER_TIME := 3.2
## 教程提示的淡出时长（秒）。教程是"读一眼就走"的信息，不是常驻 HUD。
const TUTORIAL_FADE := 0.45

const COL_TEXT := Color(0.92, 0.93, 0.89, 1.0)
const COL_DIM := Color(0.56, 0.58, 0.54, 1.0)
const COL_ACCENT := Color(0.93, 0.72, 0.30, 1.0)
const COL_DANGER := Color(0.91, 0.30, 0.22, 1.0)

var _root: Control
var _widgets: HudWidgets
var _state_text: Label
var _chapter_tag: Label
var _wave_text: Label
var _kill_text: Label
var _threat_text: Label
var _chapter_title: Label
var _chapter_sub: Label
var _tutorial_text: Label
var _accent_rule: ColorRect
var _banner_left: float = 0.0
var _tutorial_left: float = 0.0
var _chapter_no: int = 1
var _pressure_word: String = "CALM"
var _alive: int = 0

func _ready() -> void:
	layer = 2
	_build_ui()
	_connect_bus()
	_widgets.set_health(100.0, 100.0)
	# 主动拉取初始状态：Player._ready 里的 _equip(0, true) 同步发 weapon_switched，
	# 那时本 HUD 还没接线（节点顺序上 Hud 在 Player 之后），信号已被丢弃。
	# 只靠信号推送会让枪械贴图与弹药数字停在默认值。
	_pull_initial_state.call_deferred()

func _exit_tree() -> void:
	_disconnect_bus()

func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left = maxf(_banner_left - delta, 0.0)
		# 前 0.25 秒淡入、最后 0.6 秒淡出，中间保持满不透明 —— 硬切会读成掉帧
		var a: float = clampf((BANNER_TIME - _banner_left) / 0.25, 0.0, 1.0)
		if _banner_left < 0.6:
			a = _banner_left / 0.6
		if _chapter_title != null:
			_chapter_title.modulate.a = a
		if _chapter_sub != null:
			_chapter_sub.modulate.a = a

	if _tutorial_left > 0.0:
		_tutorial_left = maxf(_tutorial_left - delta, 0.0)
		if _tutorial_text != null:
			_tutorial_text.modulate.a = clampf(_tutorial_left / TUTORIAL_FADE, 0.0, 1.0)

# ── UI 构建 ─────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_widgets = HudWidgets.new()
	_root.add_child(_widgets)

	_build_status_text()

func _build_status_text() -> void:
	# 左上进度块：左侧 2x22 的琥珀色细杆把三行文字捆成一组，
	# 比给文字加框省空间，也比纯文字更容易在杂乱场景里被认出来。
	_accent_rule = ColorRect.new()
	_accent_rule.position = Vector2(12.0, 9.0)
	_accent_rule.size = Vector2(2.0, 26.0)
	_accent_rule.color = COL_ACCENT
	_accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_accent_rule)

	_chapter_tag = _label(Vector2(20.0, 6.0), "CH 01", 9, COL_ACCENT)
	_root.add_child(_chapter_tag)
	_wave_text = _label(Vector2(20.0, 17.0), "WAVE 1", 12, COL_TEXT)
	_root.add_child(_wave_text)
	_kill_text = _label(Vector2(20.0, 31.0), "KILLS 0", 9, COL_DIM)
	_root.add_child(_kill_text)

	# 上中威胁读数：压在章节横幅之上 8px，横幅出现时两者不重叠
	_threat_text = _label(Vector2(0.0, 6.0), "CALM", 9, COL_DIM)
	_threat_text.size = Vector2(LOGICAL_SIZE.x, 12.0)
	_threat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_threat_text)

	# 死亡 / 暂停提示压在画面中线偏上，避开准星
	_state_text = _label(Vector2(0, 112), "", 18, COL_TEXT)
	_state_text.size = Vector2(LOGICAL_SIZE.x, 26)
	_state_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_state_text)

	# 章节横幅：标题 + 目标，只在开场 3.2 秒存在
	_chapter_title = _label(Vector2(0, 44), "", 15, COL_TEXT)
	_chapter_title.size = Vector2(LOGICAL_SIZE.x, 19)
	_chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_title.modulate.a = 0.0
	_root.add_child(_chapter_title)
	_chapter_sub = _label(Vector2(0, 62), "", 9, COL_DIM)
	_chapter_sub.size = Vector2(LOGICAL_SIZE.x, 13)
	_chapter_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_sub.modulate.a = 0.0
	_root.add_child(_chapter_sub)

	# 教程提示压在血条上方：左下角是玩家视线余光区，不挡视野也不和准星抢位置
	_tutorial_text = _label(Vector2(12.0, 222.0), "", 9, COL_TEXT)
	_tutorial_text.size = Vector2(320.0, 13.0)
	_tutorial_text.modulate.a = 0.0
	_root.add_child(_tutorial_text)

func _label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	# 1px 描边而不是偏移投影：投影会让每个字向右下长黑边，480x270 上读成"脏"
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.62))
	l.add_theme_constant_override("outline_size", 2)
	return l

# ── 初始状态拉取 ────────────────────────────────────────────────

## 从场景里的 Player 拉一次当前武器与血量（幂等，找不到就静默跳过）
func _pull_initial_state() -> void:
	var player: Node = get_tree().get_first_node_in_group(GameLayers.GROUP_PLAYER)
	if player == null:
		return
	if player.has_method(&"active_weapon"):
		var weapon: Weapon = player.call(&"active_weapon") as Weapon
		if weapon != null and weapon.data != null:
			_apply_weapon(weapon.data)
			_widgets.set_ammo(weapon.mag_ammo(), weapon.reserve_ammo())
	var hp: Node = player.get_node_or_null(^"HealthComponent")
	if hp != null and hp.has_method(&"current_health"):
		_widgets.set_health(float(hp.call(&"current_health")),
			float(hp.get(&"max_health")))

func _apply_weapon(weapon_data: Resource) -> void:
	var wd: WeaponData = weapon_data as WeaponData
	if wd == null:
		return
	_widgets.set_weapon(wd)

# ── 事件接线 ────────────────────────────────────────────────────

func _connect_bus() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.reload_started.connect(_on_reload_started)
	EventBus.reload_cancelled.connect(_on_reload_ended)
	EventBus.reload_finished.connect(_on_reload_ended)
	EventBus.weapon_switched.connect(_on_weapon_switched)
	EventBus.player_fired.connect(_on_player_fired)
	EventBus.player_dry_fire.connect(_on_player_dry_fire)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.zombie_hit.connect(_on_zombie_hit)
	EventBus.kill_count_changed.connect(_on_kill_count_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.zombie_count_changed.connect(_on_zombie_count_changed)
	EventBus.director_pressure_changed.connect(_on_pressure_changed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.chapter_started.connect(_on_chapter_started)
	EventBus.ads_changed.connect(_on_ads_changed)
	EventBus.tutorial_step.connect(_on_tutorial_step)

func _disconnect_bus() -> void:
	var pairs: Array = [
		[EventBus.player_health_changed, _on_health_changed],
		[EventBus.ammo_changed, _on_ammo_changed],
		[EventBus.reload_started, _on_reload_started],
		[EventBus.reload_cancelled, _on_reload_ended],
		[EventBus.reload_finished, _on_reload_ended],
		[EventBus.weapon_switched, _on_weapon_switched],
		[EventBus.player_fired, _on_player_fired],
		[EventBus.player_dry_fire, _on_player_dry_fire],
		[EventBus.player_hit, _on_player_hit],
		[EventBus.zombie_hit, _on_zombie_hit],
		[EventBus.kill_count_changed, _on_kill_count_changed],
		[EventBus.wave_started, _on_wave_started],
		[EventBus.zombie_count_changed, _on_zombie_count_changed],
		[EventBus.director_pressure_changed, _on_pressure_changed],
		[EventBus.game_state_changed, _on_game_state_changed],
		[EventBus.chapter_started, _on_chapter_started],
		[EventBus.ads_changed, _on_ads_changed],
		[EventBus.tutorial_step, _on_tutorial_step],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

# ── 信号回调（纯转发到 widgets）──────────────────────────────────

func _on_health_changed(current: float, max_value: float) -> void:
	_widgets.set_health(current, max_value)

func _on_ammo_changed(mag_ammo: int, reserve_ammo: int) -> void:
	_widgets.set_ammo(mag_ammo, reserve_ammo)

func _on_reload_started(duration: float) -> void:
	_widgets.begin_reload(duration)

func _on_reload_ended() -> void:
	_widgets.end_reload()

func _on_weapon_switched(weapon_data: Resource, _slot_index: int) -> void:
	_apply_weapon(weapon_data)

func _on_player_fired(_weapon_data: Resource, _recoil: float) -> void:
	_widgets.play_fire()

func _on_player_dry_fire() -> void:
	_widgets.play_dry()

func _on_player_hit(_damage: float, _source: Node) -> void:
	_widgets.play_player_hit()

func _on_zombie_hit(_zombie: Node, _damage: float, is_weakspot: bool) -> void:
	_widgets.play_hit_marker(is_weakspot)

func _on_ads_changed(aiming: bool) -> void:
	_widgets.set_aiming(aiming)

## 教程提示：一次性显示一条，N 秒后淡出。同一条重复推送不重播，避免刷屏。
func _on_tutorial_step(_step: int) -> void:
	var text: String = Tutorial.text_for(_step)
	if text.is_empty():
		return
	if _tutorial_text != null and _tutorial_text.text == text and _tutorial_left > 0.0:
		return
	if _tutorial_text != null:
		_tutorial_text.text = text
		_tutorial_text.modulate.a = 1.0
	_tutorial_left = Tutorial.HOLD_TIME

func _on_kill_count_changed(total_kills: int) -> void:
	if _kill_text != null:
		_kill_text.text = "KILLS %d" % total_kills

func _on_wave_started(wave_index: int, _total_count: int) -> void:
	if _wave_text != null:
		_wave_text.text = "WAVE %d" % (wave_index + 1)

func _on_zombie_count_changed(alive: int) -> void:
	_alive = alive
	_refresh_threat()

func _on_pressure_changed(pressure: float) -> void:
	_pressure_word = "CALM"
	if pressure >= 0.85:
		_pressure_word = "CRITICAL"
	elif pressure >= 0.6:
		_pressure_word = "HIGH"
	elif pressure >= 0.3:
		_pressure_word = "ALERT"
	_refresh_threat()

## 威胁读数 = 压力词 + 存活数，一行两段。合并成一行而不是两个标签：
## 它们永远同时变化，拆成两行会让上中区变成一块方阵。
func _refresh_threat() -> void:
	if _threat_text == null:
		return
	_threat_text.text = "%s   %d" % [_pressure_word, _alive]
	var col: Color = COL_DIM
	if _pressure_word == "CRITICAL" or _pressure_word == "HIGH":
		col = COL_DANGER
	elif _pressure_word == "ALERT":
		col = COL_ACCENT
	_threat_text.add_theme_color_override("font_color", col)

func _on_game_state_changed(new_state: int) -> void:
	if _state_text == null:
		return
	match new_state:
		GameManager.GameState.PLAYING:
			_state_text.text = ""
		GameManager.GameState.PAUSED:
			_state_text.text = "PAUSED"
		GameManager.GameState.DEAD:
			_state_text.text = "YOU DIED   -   R TO RETRY"
		GameManager.GameState.LEVEL_COMPLETE:
			# 只有打完最后一章才会进这个状态（中间章由 GameManager 直接换章）
			_state_text.text = "DEMO CLEARED   -   R TO RESTART"
		_:
			_state_text.text = ""

## 章节开场横幅 + 左上常驻章节号。横幅负责"宣布"，常驻块负责"定位"，
## 所以横幅放标题与目标，常驻块只放编号 —— 同一句话不出现两次。
func _on_chapter_started(index: int, total: int, title: String, objective: String) -> void:
	_chapter_no = index + 1
	if _chapter_tag != null:
		_chapter_tag.text = "CH %02d / %02d" % [index + 1, total]
	if _chapter_title != null:
		_chapter_title.text = title
	if _chapter_sub != null:
		_chapter_sub.text = objective
	_banner_left = BANNER_TIME
	if _wave_text != null:
		# 换章后波次序号从 1 重新开始，这里同步复位，避免沿用上一章的 WAVE 5
		_wave_text.text = "WAVE 1"
