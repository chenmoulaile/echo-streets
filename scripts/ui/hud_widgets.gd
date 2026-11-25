## HUD 的"战斗读数"部件：血条 / 弹药 / 换弹进度 / 准星 / 命中标记 /
## 受击红闪 / 枪械贴图 / 枪口火光。
## class_name: HudWidgets
## 挂载节点类型: Control（由 Hud 用代码创建并铺满全屏）
## 设计约束（PDF）:
##   - 逻辑分辨率 480x270（project.godot 的 stretch mode=viewport + integer 放大），
##     坐标直接按 480x270 写，不做缩放换算。
##   - 像素风：贴图 texture_filter = NEAREST，禁止抗锯齿。
##   - 内置字体不含 CJK 字形，文案一律 ASCII。
## 拆出本文件的原因: hud.gd 单文件曾达 398 行，HUD 读数与事件接线混在一起，
##   改一处准星要通读全文件。
class_name HudWidgets
extends Control

const LOGICAL_SIZE := Vector2(480.0, 270.0)
## 枪口火光持续时长（秒）。低于 0.06 在 60 帧下只剩 3 帧，读不出"喷火"。
const MUZZLE_FLASH_TIME := 0.10
## 换弹条可用宽度（bg 144 减去左右各 1px 边框）
const RELOAD_BAR_WIDTH := 136.0
## 血条可用宽度（bg 120 减去左右各 1px 边框）
const HEALTH_BAR_WIDTH := 118.0
## 准星淡入淡出的逼近速度（1/秒）。10.0 ≈ 0.1 秒走完，与 ADS_TIME 0.12 同量级。
const CROSSHAIR_FADE_SPEED := 10.0

var _health_fill: ColorRect
var _health_text: Label
var _ammo_text: Label
var _reserve_text: Label
var _crosshair: Control
var _viewmodel: Viewmodel
var _muzzle_flash: ColorRect
var _muzzle_mat: ShaderMaterial
var _muzzle_left: float = 0.0
var _reload_bar_bg: ColorRect
var _reload_bar_fill: ColorRect
var _damage_flash: ColorRect
var _hit_marker: Control

var _crosshair_color: Color = Color(0.86, 0.88, 0.82, 0.9)
## 准星不透明度目标值。开镜 → 0（准星会挡住瞄准点），腰射 → 1。
var _crosshair_target: float = 1.0
var _damage_alpha: float = 0.0
var _hit_alpha: float = 0.0
var _reloading: bool = false
var _reload_total: float = 1.0
var _reload_left: float = 0.0

func _ready() -> void:
	name = "HudWidgets"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 受击红闪最先加入 → 位于最底层
	_damage_flash = _full_rect_rect(Color(0.62, 0.05, 0.05, 0.0))
	add_child(_damage_flash)
	_build_health()
	_build_ammo()
	_build_reload_bar()
	_build_weapon_icon()
	_build_muzzle_flash()
	_build_crosshair()
	_build_hit_marker()

# ── 构建 ────────────────────────────────────────────────────────

func _build_health() -> void:
	# 字号 9 的 Label 行高约 13px，所以文字放在 232、血条压到 252，留 7px 间隙；
	# 旧版文字 232 + 血条 246 首尾相接，截帧里糊成一块。
	add_child(_rect(Vector2(12, 252), Vector2(120, 11), Color(0.05, 0.05, 0.07, 0.82)))
	_health_fill = _rect(Vector2(13, 253), Vector2(HEALTH_BAR_WIDTH, 9),
		Color(0.55, 0.13, 0.13, 1.0))
	add_child(_health_fill)
	_health_text = _label(Vector2(12, 232), "HP 100/100", 9, Color(0.86, 0.88, 0.84, 1.0))
	add_child(_health_text)

func _build_ammo() -> void:
	# 弹药放右上角而不是右下：右下被第一人称枪械 viewmodel 占据
	# （实测枪贴图 276~476 x 120~270 与旧右下位置完全重叠，弹药被遮掉半个字）。
	_ammo_text = _label(Vector2(388, 26), "12", 26, Color(0.94, 0.90, 0.74, 1.0))
	_ammo_text.size = Vector2(80, 32)
	_ammo_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_ammo_text)
	_reserve_text = _label(Vector2(388, 58), "/ 60", 11, Color(0.72, 0.72, 0.66, 1.0))
	_reserve_text.size = Vector2(80, 16)
	_reserve_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_reserve_text)

func _build_reload_bar() -> void:
	# 换弹条贴在准星正下方：换弹时机是核心博弈点，视线不能离开准星。
	_reload_bar_bg = _rect(Vector2(168, 152), Vector2(144, 5), Color(0.04, 0.04, 0.06, 0.9))
	_reload_bar_bg.visible = false
	add_child(_reload_bar_bg)
	_reload_bar_fill = _rect(Vector2(169, 153), Vector2(0, 3), Color(0.92, 0.72, 0.28, 1.0))
	_reload_bar_fill.visible = false
	add_child(_reload_bar_fill)

func _build_weapon_icon() -> void:
	_viewmodel = Viewmodel.new()
	add_child(_viewmodel)

func _build_muzzle_flash() -> void:
	# 枪口火光用 ColorRect 而不是 TextureRect —— 无 texture 的 TextureRect 整节点
	# 不绘制，着色器完全不生效（见 shaders/muzzle_flash.gdshader 文件头）。
	# 尺寸 84x84：小于 64 读成一颗点，大于 110 会盖住准星左侧的视野。
	_muzzle_flash = ColorRect.new()
	_muzzle_flash.name = "MuzzleFlash"
	_muzzle_flash.size = Vector2(84, 84)
	_muzzle_flash.position = _viewmodel.muzzle_position() - _muzzle_flash.size * 0.5
	_muzzle_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muzzle_mat = ShaderMaterial.new()
	_muzzle_mat.shader = load("res://shaders/muzzle_flash.gdshader") as Shader
	if _muzzle_mat.shader != null:
		# Compatibility 渲染器无泛光，emission_boost 用 1.2 而不是 2.5，否则过曝成白块
		_muzzle_mat.set_shader_parameter(&"emission_boost", 1.2)
		_muzzle_mat.set_shader_parameter(&"size", 0.8)
		_muzzle_mat.set_shader_parameter(&"lifetime", 1.0)
	_muzzle_flash.material = _muzzle_mat
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)

func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.size = Vector2(16, 16)
	_crosshair.position = (LOGICAL_SIZE - _crosshair.size) * 0.5
	add_child(_crosshair)
	# 四段短线 + 中心点，Doom 式极简准星
	_crosshair.add_child(_rect(Vector2(7, 0), Vector2(2, 5), _crosshair_color))
	_crosshair.add_child(_rect(Vector2(7, 11), Vector2(2, 5), _crosshair_color))
	_crosshair.add_child(_rect(Vector2(0, 7), Vector2(5, 2), _crosshair_color))
	_crosshair.add_child(_rect(Vector2(11, 7), Vector2(5, 2), _crosshair_color))
	_crosshair.add_child(_rect(Vector2(7, 7), Vector2(2, 2), _crosshair_color))

func _build_hit_marker() -> void:
	_hit_marker = Control.new()
	_hit_marker.name = "HitMarker"
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marker.size = Vector2(20, 20)
	_hit_marker.position = (LOGICAL_SIZE - _hit_marker.size) * 0.5
	_hit_marker.modulate.a = 0.0
	add_child(_hit_marker)
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_hit_marker.add_child(_rect(Vector2(9, 9) + dir * 5.0, Vector2(3, 3), Color(1, 1, 1, 1)))

# ── 控件工厂 ────────────────────────────────────────────────────

func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _full_rect_rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

# ── 逐帧动画 ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# 火光跟着枪口走（viewmodel 内部把后坐位移与开镜位移都算进 muzzle_position）
	if _muzzle_flash != null:
		_muzzle_flash.position = _viewmodel.muzzle_position() - _muzzle_flash.size * 0.5

	# 准星淡出/淡入。开镜时准星必须让位 —— 瞄准点就是屏幕中心，
	# 留着准星反而挡住目标；腰射时立刻回来，慢一拍会被读成"准星丢了"。
	if _crosshair != null:
		_crosshair.modulate.a = move_toward(
			_crosshair.modulate.a, _crosshair_target, CROSSHAIR_FADE_SPEED * delta)

	if _damage_alpha > 0.0:
		_damage_alpha = maxf(_damage_alpha - delta * 1.8, 0.0)
		_damage_flash.color.a = _damage_alpha * 0.42

	if _hit_alpha > 0.0:
		_hit_alpha = maxf(_hit_alpha - delta * 3.2, 0.0)
		_hit_marker.modulate.a = _hit_alpha

	if _muzzle_left > 0.0:
		_muzzle_left = maxf(_muzzle_left - delta, 0.0)
		if _muzzle_mat != null:
			_muzzle_mat.set_shader_parameter(&"lifetime",
				clampf(1.0 - _muzzle_left / MUZZLE_FLASH_TIME, 0.0, 1.0))
		if _muzzle_left <= 0.0:
			_muzzle_flash.visible = false

	if _reloading:
		_reload_left = maxf(_reload_left - delta, 0.0)
		var ratio: float = 0.0
		if _reload_total > 0.0:
			ratio = clampf(1.0 - _reload_left / _reload_total, 0.0, 1.0)
		_reload_bar_fill.size.x = RELOAD_BAR_WIDTH * ratio

# ── 外部驱动接口（由 Hud 调用）────────────────────────────────────

func set_health(current: float, max_value: float) -> void:
	var ratio: float = 0.0
	if max_value > 0.0:
		ratio = clampf(current / max_value, 0.0, 1.0)
	if _health_fill != null:
		_health_fill.size.x = HEALTH_BAR_WIDTH * ratio
		# 血量越低越红（低血必须有强反馈）
		_health_fill.color = Color(0.55, 0.13, 0.13, 1.0).lerp(
			Color(0.92, 0.22, 0.16, 1.0), 1.0 - ratio)
	if _health_text != null:
		_health_text.text = "HP %d/%d" % [int(round(current)), int(round(max_value))]

func set_ammo(mag_ammo: int, reserve_ammo: int) -> void:
	if _ammo_text != null:
		_ammo_text.text = str(mag_ammo)
		# 空仓变红，逼玩家感知换弹时机
		_ammo_text.add_theme_color_override("font_color",
			Color(0.92, 0.26, 0.20, 1.0) if mag_ammo <= 0
			else Color(0.94, 0.90, 0.74, 1.0))
	if _reserve_text != null:
		_reserve_text.text = "/ %d" % reserve_ammo

## 切枪：viewmodel 换成对应武器的帧组（手枪 146x150 / 霰弹枪 259x150，落位不同）
func set_weapon(data: WeaponData) -> void:
	if _viewmodel == null or data == null:
		return
	_viewmodel.set_weapon(data.shotgun_viewmodel)

## 开镜：枪身平移到瞄准姿态 + 准星淡出。两者必须同时驱动 ——
## 只动枪会让准星压在瞄准点上，只动准星会让枪留在腰射位置。
func set_aiming(on: bool) -> void:
	_crosshair_target = 0.0 if on else 1.0
	if _viewmodel != null:
		_viewmodel.set_aiming(on)

func begin_reload(duration: float) -> void:
	_reloading = true
	_reload_total = maxf(duration, 0.01)
	_reload_left = _reload_total
	if _viewmodel != null:
		_viewmodel.begin_reload(duration)
	if _reload_bar_bg != null:
		_reload_bar_bg.visible = true
		_reload_bar_fill.visible = true
		_reload_bar_fill.size.x = 0.0

func end_reload() -> void:
	_reloading = false
	if _viewmodel != null:
		_viewmodel.end_reload()
	if _reload_bar_bg != null:
		_reload_bar_bg.visible = false
		_reload_bar_fill.visible = false

## 开火反馈：viewmodel 播开火帧 + 枪口火光。每发换随机种子 —— 着色器靠
## random_seed 决定花瓣旋转角与长度，同一 seed 会看出重复。
func play_fire() -> void:
	if _viewmodel != null:
		_viewmodel.play_fire()
	if _muzzle_mat == null:
		return
	_muzzle_left = MUZZLE_FLASH_TIME
	_muzzle_flash.visible = true
	_muzzle_mat.set_shader_parameter(&"random_seed", randf())
	_muzzle_mat.set_shader_parameter(&"lifetime", 0.0)

## 空仓扣扳机：换成空仓姿势，不放火光
func play_dry() -> void:
	if _viewmodel != null:
		_viewmodel.play_dry()

func play_player_hit() -> void:
	_damage_alpha = 1.0

func play_hit_marker(is_weakspot: bool) -> void:
	_hit_alpha = 1.0
	_hit_marker.modulate = Color(1.0, 0.86, 0.30, 1.0) if is_weakspot else Color(1, 1, 1, 1)
