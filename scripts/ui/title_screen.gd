## 主菜单：启动后的第一屏。之前项目直接进 main.tscn，玩家一睁眼就在打丧尸，
## 既没有"开始"的心理契约，也没有退出口。
## class_name: TitleScreen
## 挂载节点类型: CanvasLayer（title.tscn 里，UI 全代码建）
## 依赖信号:
##   发出 —— EventBus.run_started（点 START 时；关卡侧教程推进器据此判断这是新一局）
## 子节点假设: 同节点下挂一个 SettingsPanel 实例（title.tscn 里已接）
##
## 三个约束:
##   1. 鼠标必须可见 —— 上一局如果是在 main.tscn 里死掉再回标题，mouse_mode 还是
##      CAPTURED，玩家会看到画面却点不到按钮。
##   2. 按钮不吃 UI 主题默认值 —— 项目逻辑分辨率 480x270，默认主题字号在
##      这个尺度下会撑破布局，全部用 add_theme_font_size_override 显式指定。
##   3. 只在按下 START 的同一帧切场景 —— 先 emit run_started 再 change_scene，
##      否则信号发给了正在被释放的场景树。
extends CanvasLayer

const TITLE_TEXT := "ECHO STREETS"
const SUB_TEXT := "PIXEL ZOMBIE FPS"
const FOOT_TEXT := "WASD MOVE   LMB FIRE   O SETTINGS   ESC PAUSE"
const MAIN_SCENE := "res://scenes/main.tscn"

const BG_COLOR := Color(0.043, 0.051, 0.071, 1.0)
const ACCENT := Color(0.34, 0.84, 0.90, 1.0)
const TEXT_COLOR := Color(0.88, 0.90, 0.84, 1.0)
const DIM_COLOR := Color(0.55, 0.60, 0.60, 1.0)
const BTN_FILL := Color(0.10, 0.12, 0.16, 1.0)
const BTN_HOVER := Color(0.17, 0.21, 0.27, 1.0)
const BTN_PRESS := Color(0.26, 0.32, 0.40, 1.0)

const BTN_SIZE := Vector2(148.0, 22.0)
const BTN_GAP := 6.0
const BTN_TOP := 132.0

var _settings: SettingsPanel
var _buttons: Array[Button] = []
var _blink: float = 0.0
var _prompt: Label
var _leaving: bool = false

func _ready() -> void:
	layer = 3
	# 上一局可能把鼠标锁在视角里，回标题必须解锁，否则按钮点不到
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.ui_modal = false
	GameSettings.ensure_loaded()
	_settings = get_node_or_null(^"SettingsPanel") as SettingsPanel
	_build_ui()

# ── UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 地平线式暗带：给标题一个"地面"，避免整屏纯色像加载失败
	var band := ColorRect.new()
	band.color = Color(0.07, 0.08, 0.10, 1.0)
	band.position = Vector2(0.0, 196.0)
	band.size = Vector2(480.0, 74.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	var accent := ColorRect.new()
	accent.color = ACCENT
	accent.position = Vector2(0.0, 194.0)
	accent.size = Vector2(480.0, 2.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var title := _label(Vector2(0.0, 54.0), TITLE_TEXT, 34, TEXT_COLOR)
	title.size = Vector2(480.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := _label(Vector2(0.0, 96.0), SUB_TEXT, 11, DIM_COLOR)
	sub.size = Vector2(480.0, 14.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var x: float = (480.0 - BTN_SIZE.x) * 0.5
	_add_button(Vector2(x, BTN_TOP), "START", _on_start)
	_add_button(Vector2(x, BTN_TOP + BTN_SIZE.y + BTN_GAP), "SETTINGS", _on_settings)
	_add_button(Vector2(x, BTN_TOP + (BTN_SIZE.y + BTN_GAP) * 2.0), "QUIT", _on_quit)

	_prompt = _label(Vector2(0.0, 244.0), "ENTER TO START", 10, ACCENT)
	_prompt.size = Vector2(480.0, 12.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	var foot := _label(Vector2(0.0, 258.0), FOOT_TEXT, 9, DIM_COLOR)
	foot.size = Vector2(480.0, 10.0)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)

func _label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _add_button(pos: Vector2, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.position = pos
	b.size = BTN_SIZE
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_stylebox_override("normal", _box(BTN_FILL))
	b.add_theme_stylebox_override("hover", _box(BTN_HOVER))
	b.add_theme_stylebox_override("pressed", _box(BTN_PRESS))
	b.pressed.connect(cb)
	_buttons.append(b)
	add_child(b)

func _box(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = ACCENT
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(0)
	return sb

# ── 交互 ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# "ENTER TO START" 呼吸，告诉玩家这一屏是活的
	_blink += delta
	_prompt.modulate.a = 0.45 + 0.55 * absf(sin(_blink * 2.2))

func _unhandled_input(event: InputEvent) -> void:
	if _settings != null and _settings.is_open():
		return
	if event.is_action_pressed(&"settings"):
		_on_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept"):
		_on_start()
		get_viewport().set_input_as_handled()

func _on_start() -> void:
	if _leaving:
		return
	_leaving = true
	EventBus.run_started.emit()
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_settings() -> void:
	if _settings == null:
		return
	_settings.toggle()

func _on_quit() -> void:
	get_tree().quit()
