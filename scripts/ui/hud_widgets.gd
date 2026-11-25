## HUD 的"战斗读数"部件：血量 / 弹药 / 准星 / 命中反馈 / 受击红闪 /
## 枪械贴图 / 枪口火光。
## class_name: HudWidgets
## 挂载节点类型: Control（由 Hud 用代码创建并铺满全屏）
##
## 设计口径（用户 m11566：高级、简洁）：
##   - 全部 1px 硬边线，不用圆角、不用投影块、不用实心色块堆叠。
##   - 文字一律小字号 + 低饱和暖白，只有"正在发生的事"（换弹、低血、弱点）
##     才允许出现彩色。
##   - 四个角的信息密度：左上=进度（章节/波次/击杀/威胁），右上=弹药，
##     左下=血量。中下与右下留给枪，不叠任何读数。
##   - 逻辑分辨率 480x270（stretch mode=viewport + integer），坐标直接按它写。
class_name HudWidgets
extends Control

const LOGICAL_SIZE := Vector2(480.0, 270.0)
## 枪口火光持续时长（秒）。低于 0.06 在 60 帧下只剩 3 帧，读不出"喷火"。
const MUZZLE_FLASH_TIME := 0.10
const HEALTH_BAR_W := 132.0
const HEALTH_BAR_H := 5.0

const COL_TEXT := Color(0.90, 0.91, 0.87, 1.0)
const COL_TEXT_DIM := Color(0.58, 0.60, 0.56, 1.0)
const COL_ACCENT := Color(0.93, 0.72, 0.30, 1.0)
const COL_DANGER := Color(0.91, 0.30, 0.22, 1.0)

## 血条：轨道 + 填充 + 三分隔刻度。内联类而不是单独文件 —— 它只有 _draw，
## 没有对外接口，拆出去反而要在两个文件之间跳。
class HealthBar extends Control:
	## 内部类不能读外部脚本的常量（GDScript 内部类不继承外层），所以自己带一份。
	const DANGER := Color(0.91, 0.30, 0.22, 1.0)

	var ratio: float = 1.0
	## 低血脉冲相位，0..1 循环
	var pulse: float = 0.0

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		# 轨道压得比填充深：血条在 ch01 白石地面上是浅底浅条，没有深轨道就没有轮廓
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.03, 0.03, 0.04, 0.78))
		var fill: Color = Color(0.90, 0.91, 0.87, 0.95)
		if ratio < 0.35:
			# 低血：换成危险色并随 pulse 呼吸。只有这一处允许 HUD 主动发光。
			var k: float = 0.55 + 0.45 * sin(pulse * TAU)
			fill = Color(DANGER.r, DANGER.g, DANGER.b, 0.65 + 0.35 * k)
		# 填充内缩 1px，让深轨道始终露一圈 —— 这就是血条的"边框"，
		# 不用再额外画描边（描边画在填充上会把填充压细，血少时看起来像坏了）
		var fill_w: float = maxf(w * clampf(ratio, 0.0, 1.0) - 2.0, 0.0)
		draw_rect(Rect2(1.0, 1.0, fill_w, h - 2.0), fill)
		for i: int in range(1, 3):
			var x: float = w * float(i) / 3.0
			draw_line(Vector2(x, 1.0), Vector2(x, h - 1.0), Color(0.0, 0.0, 0.0, 0.42), 1.0, false)

var _health_bar: HealthBar
var _health_text: Label
var _ammo_text: Label
var _reserve_text: Label
var _crosshair: Crosshair
var _hit_marker: HitMarker
var _viewmodel: Viewmodel
var _muzzle_flash: ColorRect
var _muzzle_mat: ShaderMaterial
var _muzzle_left: float = 0.0
var _damage_flash: ColorRect
var _damage_alpha: float = 0.0
var _health_pulse: float = 0.0
var _reloading: bool = false
var _reload_total: float = 1.0
var _reload_left: float = 0.0

func _ready() -> void:
	name = "HudWidgets"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 受击红闪最先加入 → 位于最底层
	_damage_flash = _full_rect_rect(Color(0.55, 0.04, 0.03, 0.0))
	add_child(_damage_flash)
	_build_health()
	_build_ammo()
	_build_weapon_icon()
	_build_muzzle_flash()
	_build_crosshair()
	_build_hit_marker()

# ── 构建 ────────────────────────────────────────────────────────

func _build_health() -> void:
	_health_bar = HealthBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.position = Vector2(12.0, 252.0)
	_health_bar.size = Vector2(HEALTH_BAR_W, HEALTH_BAR_H)
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_bar)
	# 数字压在血条右端上方：与条同一条基线，不额外占纵向空间
	_health_text = _label(Vector2(12.0, 238.0), "100", 9, COL_TEXT_DIM)
	_health_text.size = Vector2(HEALTH_BAR_W, 12.0)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_health_text)

func _build_ammo() -> void:
	# 弹药放右上角：右下被第一人称枪械 viewmodel 占据（枪身底边与屏幕底边齐平）。
	# 弹匣数与备弹竖排右对齐 —— 横排时 "12 / 60" 会挤成一条，字号差读不出层级。
	_ammo_text = _label(Vector2(392.0, 10.0), "12", 22, COL_TEXT)
	_ammo_text.size = Vector2(76.0, 26.0)
	_ammo_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_ammo_text)
	_reserve_text = _label(Vector2(392.0, 34.0), "/ 60", 9, COL_TEXT_DIM)
	_reserve_text.size = Vector2(76.0, 13.0)
	_reserve_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_reserve_text)

func _build_weapon_icon() -> void:
	_viewmodel = Viewmodel.new()
	add_child(_viewmodel)

func _build_muzzle_flash() -> void:
	# 枪口火光用 ColorRect 而不是 TextureRect —— 无 texture 的 TextureRect 整节点
	# 不绘制，着色器完全不生效（见 shaders/muzzle_flash.gdshader 文件头）。
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
	_crosshair = Crosshair.new()
	# size 必须在 add_child 之前显式给：Crosshair._ready() 里也会设一次，
	# 但 _ready 要等入树才跑，这里若读 size 会拿到 (0,0)，准星会偏到左上角。
	_crosshair.size = Crosshair.BOX
	_crosshair.position = (LOGICAL_SIZE - _crosshair.size) * 0.5
	add_child(_crosshair)

func _build_hit_marker() -> void:
	_hit_marker = HitMarker.new()
	_hit_marker.size = HitMarker.BOX
	_hit_marker.position = (LOGICAL_SIZE - _hit_marker.size) * 0.5
	add_child(_hit_marker)

# ── 控件工厂 ────────────────────────────────────────────────────

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
	# 用 1px 描边而不是偏移投影：偏移投影会让每个字向右下长出一块黑边，
	# 在 480x270 上读起来是"脏"。描边只保可读性，不改字形轮廓。
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.62))
	l.add_theme_constant_override("outline_size", 2)
	return l

# ── 逐帧动画 ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# 火光跟着枪口走（viewmodel 内部把后坐位移与开镜位移都算进 muzzle_position）
	if _muzzle_flash != null:
		_muzzle_flash.position = _viewmodel.muzzle_position() - _muzzle_flash.size * 0.5

	if _damage_alpha > 0.0:
		_damage_alpha = maxf(_damage_alpha - delta * 1.8, 0.0)
		_damage_flash.color.a = _damage_alpha * 0.38

	if _health_bar != null and _health_bar.ratio < 0.35:
		_health_pulse = fmod(_health_pulse + delta * 1.6, 1.0)
		_health_bar.pulse = _health_pulse
		_health_bar.queue_redraw()

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
		if _crosshair != null:
			_crosshair.set_reload(ratio)

# ── 外部驱动接口（由 Hud 调用）────────────────────────────────────

func set_health(current: float, max_value: float) -> void:
	var ratio: float = 0.0
	if max_value > 0.0:
		ratio = clampf(current / max_value, 0.0, 1.0)
	if _health_bar != null:
		_health_bar.ratio = ratio
		_health_bar.queue_redraw()
	if _health_text != null:
		_health_text.text = str(int(round(current)))
		_health_text.add_theme_color_override("font_color",
			COL_DANGER if ratio < 0.35 else COL_TEXT_DIM)

func set_ammo(mag_ammo: int, reserve_ammo: int) -> void:
	if _ammo_text != null:
		_ammo_text.text = str(mag_ammo)
		# 空仓变红，逼玩家感知换弹时机
		_ammo_text.add_theme_color_override("font_color",
			COL_DANGER if mag_ammo <= 0 else COL_TEXT)
	if _reserve_text != null:
		_reserve_text.text = "/ %d" % reserve_ammo

## 切枪：viewmodel 换成对应武器的帧组（手枪 229x188 / 霰弹枪 259x150，落位不同）
func set_weapon(data: WeaponData) -> void:
	if _viewmodel == null or data == null:
		return
	_viewmodel.set_weapon(data.shotgun_viewmodel)

## 开镜：枪身平移到瞄准姿态 + 准星收拢淡出。两者必须同时驱动 ——
## 只动枪会让准星压在瞄准点上，只动准星会让枪留在腰射位置。
func set_aiming(on: bool) -> void:
	if _crosshair != null:
		_crosshair.set_aiming(on)
	if _viewmodel != null:
		_viewmodel.set_aiming(on)

func begin_reload(duration: float) -> void:
	_reloading = true
	_reload_total = maxf(duration, 0.01)
	_reload_left = _reload_total
	if _viewmodel != null:
		_viewmodel.begin_reload(duration)
	if _crosshair != null:
		_crosshair.set_reload(0.0)

func end_reload() -> void:
	_reloading = false
	if _viewmodel != null:
		_viewmodel.end_reload()
	if _crosshair != null:
		_crosshair.set_reload(-1.0)

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
	if _hit_marker != null:
		_hit_marker.fire(is_weakspot)
