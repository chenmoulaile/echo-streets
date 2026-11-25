## 设置面板：鼠标灵敏度 / 操控方案 / 主音量。
## class_name: SettingsPanel
## 挂载节点类型: CanvasLayer（title.tscn 与 main.tscn 各挂一个实例，代码建 UI）
## 依赖信号:
##   监听 —— 无（面板自己读 GameSettings，写也经 GameSettings 的 setter）
##   发出 —— 经 GameSettings 间接触发 EventBus.settings_changed / input_scheme_changed
## 节点路径假设: 无。全部子节点在 _build_ui() 里用代码创建。
##
## 三个必须成立的约束（踩过才知道）:
##   1. process_mode = PROCESS_MODE_ALWAYS —— 打开面板会暂停场景树（不然玩家在
##      调灵敏度时被丧尸咬死），暂停节点默认不处理输入，面板自己必须先免疫暂停。
##   2. 打开时置 GameManager.ui_modal = true —— 否则 ESC 同时被面板和 GameManager
##      收到，面板刚关就被 pause_game() 接管，读起来像"关不掉"。
##   3. 关闭时把鼠标模式还给游戏 —— 漏这一步玩家回到游戏里转不了视角。
class_name SettingsPanel
extends CanvasLayer

const PANEL_SIZE := Vector2(300.0, 168.0)
const ROW_H := 26.0
const BG_COLOR := Color(0.05, 0.06, 0.08, 0.86)
const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.96)
const BORDER_COLOR := Color(0.55, 0.62, 0.68, 1.0)
const TEXT_COLOR := Color(0.88, 0.90, 0.84, 1.0)
const DIM_COLOR := Color(0.62, 0.66, 0.62, 1.0)

var _dim: ColorRect
var _panel: Panel
var _sens_label: Label
var _sens_slider: HSlider
var _vol_label: Label
var _vol_slider: HSlider
var _scheme_button: Button
var _paused_by_us: bool = false

func _ready() -> void:
	# 暂停时也要能操作滑条与按钮
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	GameSettings.ensure_loaded()
	_build_ui()
	close()

# ── 开关 ────────────────────────────────────────────────────────

func is_open() -> bool:
	return visible

func open() -> void:
	GameSettings.ensure_loaded()
	_sync_from_settings()
	visible = true
	GameManager.ui_modal = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 只在真正玩的时候暂停。标题界面（BOOT）暂停没有意义，而且会挡住按钮动画。
	if GameManager.is_playing() and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true

func close() -> void:
	visible = false
	GameManager.ui_modal = false
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
	# 回到游戏才抓鼠标。标题界面保持可见，否则点不到 START。
	if GameManager.is_playing():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

## ESC / O 关闭。面板先吃到事件并标记已处理，GameManager 的暂停逻辑就不会抢。
func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed(&"settings"):
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"settings"):
		close()
		get_viewport().set_input_as_handled()

# ── UI 构建 ─────────────────────────────────────────────────────

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = BG_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Panel.new()
	_panel.size = PANEL_SIZE
	_panel.position = (Vector2(480.0, 270.0) - PANEL_SIZE) * 0.5
	_panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, BORDER_COLOR))
	add_child(_panel)

	var title: Label = _label(Vector2(16.0, 10.0), "SETTINGS", 14, TEXT_COLOR)
	_panel.add_child(title)
	var hint: Label = _label(Vector2(16.0, PANEL_SIZE.y - 22.0),
		"ESC / O CLOSE", 10, DIM_COLOR)
	_panel.add_child(hint)

	_sens_label = _label(Vector2(16.0, 38.0), "", 11, TEXT_COLOR)
	_panel.add_child(_sens_label)
	_sens_slider = _slider(Vector2(16.0, 54.0), GameSettings.SENSITIVITY_MIN,
		GameSettings.SENSITIVITY_MAX, 0.05)
	_sens_slider.value_changed.connect(_on_sensitivity_changed)
	_panel.add_child(_sens_slider)

	_vol_label = _label(Vector2(16.0, 78.0), "", 11, TEXT_COLOR)
	_panel.add_child(_vol_label)
	_vol_slider = _slider(Vector2(16.0, 94.0), 0.0, 1.0, 0.05)
	_vol_slider.value_changed.connect(_on_volume_changed)
	_panel.add_child(_vol_slider)

	_scheme_button = Button.new()
	_scheme_button.position = Vector2(16.0, 118.0)
	_scheme_button.size = Vector2(PANEL_SIZE.x - 32.0, ROW_H)
	_scheme_button.add_theme_font_size_override("font_size", 11)
	_scheme_button.add_theme_color_override("font_color", TEXT_COLOR)
	_scheme_button.add_theme_stylebox_override("normal", _box(Color(0.16, 0.18, 0.22, 1.0), BORDER_COLOR))
	_scheme_button.add_theme_stylebox_override("hover", _box(Color(0.22, 0.25, 0.30, 1.0), BORDER_COLOR))
	_scheme_button.add_theme_stylebox_override("pressed", _box(Color(0.30, 0.34, 0.40, 1.0), BORDER_COLOR))
	_scheme_button.pressed.connect(_on_scheme_pressed)
	_panel.add_child(_scheme_button)

func _label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _slider(pos: Vector2, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = Vector2(PANEL_SIZE.x - 32.0, 16.0)
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	return s

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	return sb

# ── 数据同步 ────────────────────────────────────────────────────

## 面板显示永远从 GameSettings 拉，不保留自己的副本 ——
## 两处各存一份必然漂移（重启后滑条位置与真实值不一致）。
func _sync_from_settings() -> void:
	_sens_slider.set_value_no_signal(GameSettings.sensitivity)
	_vol_slider.set_value_no_signal(GameSettings.volume)
	_refresh_text()

func _refresh_text() -> void:
	_sens_label.text = "MOUSE SENSITIVITY   %.2f" % GameSettings.sensitivity
	_vol_label.text = "MASTER VOLUME   %d%%" % int(round(GameSettings.volume * 100.0))
	_scheme_button.text = "CONTROLS:  " + GameSettings.scheme_name(GameSettings.scheme)

func _on_sensitivity_changed(value: float) -> void:
	GameSettings.set_sensitivity(value)
	_refresh_text()

func _on_volume_changed(value: float) -> void:
	GameSettings.set_volume(value)
	_refresh_text()

## 两套方案来回切。apply_scheme 会整表擦除后重绑，所以只需给出目标值。
func _on_scheme_pressed() -> void:
	var next: int = GameSettings.SCHEME_CLASSIC \
		if GameSettings.scheme == GameSettings.SCHEME_L4D else GameSettings.SCHEME_L4D
	GameSettings.set_scheme(next)
	_refresh_text()
	EventBus.settings_changed.emit()
