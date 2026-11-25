## 准星 + 换弹进度环，全部用 _draw() 光栅化，不用子节点拼色块。
## class_name: Crosshair
## 挂载节点类型: Control（40x40，居中压在屏幕中心）
##
## 为什么准星要自己画：
##   旧版用 5 个 ColorRect 拼四段短线 + 中心点。2px 宽的方块在 480x270 上
##   读起来是"四个矩形"，没有收束感；而准星的全部意义是**把视线收束到一点**。
##   用 1px 硬边线 + 内细外粗的双层结构，视觉重量才集中到中心。
##
## 为什么换弹进度做成环：
##   进度条挂在准星下方时，视线要下移才能读进度 —— 换弹恰恰是最不能移开
##   视线的时刻。环包在准星外侧，进度与瞄准点共用同一个视觉焦点。
class_name Crosshair
extends Control

## 环半径。准星四段线的最外端是 7px，环放 13px 才不重叠。
const RING_RADIUS := 13.0
const RING_THICK := 1.0
## 控件边长。调用方必须在 add_child 之前用它设 size —— _ready() 里设太晚，
## 调用方算居中位置时读到的还是 (0,0)。
const BOX := Vector2(40.0, 40.0)
## 换弹环颜色。与 HUD 主色（暖白）区分开：进度是"正在发生的事"，用琥珀。
const RING_COLOR := Color(0.93, 0.72, 0.30, 1.0)
const RING_BACK := Color(0.05, 0.05, 0.06, 0.55)

const ARM_INNER := 2.0
const ARM_OUTER := 6.0
const ARM_THICK := 1.0
const DOT_SIZE := 1.0

const COL_MAIN := Color(0.93, 0.95, 0.90, 1.0)
## 1px 暗边：白石地面（ch01）上纯白准星会彻底消失，暗边是唯一可读性保障。
const COL_EDGE := Color(0.0, 0.0, 0.0, 0.42)

var _reload_ratio: float = -1.0
var _alpha: float = 1.0
var _target_alpha: float = 1.0
## 开镜时准星收拢：腰射 1.0，开镜 0.55 —— 视觉上"贴腮"时准星也跟着聚。
var _gather: float = 1.0

func _ready() -> void:
	name = "Crosshair"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BOX

func set_aiming(on: bool) -> void:
	_target_alpha = 0.0 if on else 1.0
	_gather = 0.55 if on else 1.0

## ratio < 0 表示不在换弹（隐藏环）
func set_reload(ratio: float) -> void:
	_reload_ratio = ratio
	queue_redraw()

func _process(delta: float) -> void:
	var next_alpha: float = move_toward(_alpha, _target_alpha, 10.0 * delta)
	if not is_equal_approx(next_alpha, _alpha):
		_alpha = next_alpha
		# 只在真的变化时重绘：准星每帧无脑 queue_redraw 会让整个 CanvasLayer
		# 每帧重建绘制列表，实测在 480x270 上也要 0.2ms，白烧。
		queue_redraw()

func _draw() -> void:
	if _alpha <= 0.01 and _reload_ratio < 0.0:
		return
	var c: Vector2 = size * 0.5
	var a: float = _alpha

	if _reload_ratio >= 0.0:
		var back := Color(RING_BACK.r, RING_BACK.g, RING_BACK.b, RING_BACK.a)
		draw_arc(c, RING_RADIUS, 0.0, TAU, 40, back, RING_THICK, false)
		var sweep: float = TAU * clampf(_reload_ratio, 0.0, 1.0)
		if sweep > 0.001:
			draw_arc(c, RING_RADIUS, -PI * 0.5, -PI * 0.5 + sweep, 40,
				RING_COLOR, RING_THICK, false)

	if a <= 0.01:
		return
	var main := Color(COL_MAIN.r, COL_MAIN.g, COL_MAIN.b, COL_MAIN.a * a)
	var edge := Color(COL_EDGE.r, COL_EDGE.g, COL_EDGE.b, COL_EDGE.a * a)
	var inner: float = ARM_INNER * _gather
	var outer: float = ARM_OUTER * _gather

	# 四向臂 + 中心点：每条先画 1px 暗边（右下偏移 1px）再画亮线
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p0: Vector2 = c + dir * inner
		var p1: Vector2 = c + dir * outer
		draw_line(p0 + Vector2(0.0, 1.0), p1 + Vector2(0.0, 1.0), edge, ARM_THICK, false)
		draw_line(p0, p1, main, ARM_THICK, false)

	var half: float = DOT_SIZE * 0.5
	var d0: Vector2 = c - Vector2(half, half)
	draw_rect(Rect2(d0 + Vector2(0.0, 1.0), Vector2(DOT_SIZE, DOT_SIZE)), edge)
	draw_rect(Rect2(d0, Vector2(DOT_SIZE, DOT_SIZE)), main)
