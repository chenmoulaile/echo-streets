## 命中反馈：四道 1px 斜向刻线，从准星中心向外弹开并淡出。
## class_name: HitMarker
## 挂载节点类型: Control（由 HudWidgets 创建，24x24，居中压在准星上）
##
## 为什么不用 ColorRect 拼方块（旧版做法）：
##   四个 3x3 实心白方块在 480x270 的像素屏上就是四个噪点，没有方向性、
##   没有时间结构，读起来像调试用的定位标记。命中的"手感"来自三件事 ——
##   起始半径小、向外弹开、快速淡出；缺任何一件都读成"闪了一下"。
##
## 为什么用 _draw() 画线而不是摆一堆子节点：
##   刻线要沿 45° 方向、要精确 1px 宽、还要每帧改长度和半径。子节点做不到
##   旋转 45° 还能保持像素对齐（Control.rotation 会走双线性采样，1px 线
##   转完变成 2px 灰边）。draw_line 在 canvas 上直接光栅化，width=1、
##   antialiased=false 就是硬边像素。
class_name HitMarker
extends Control

## 整条反馈的生命周期（秒）。0.22 秒 ≈ 13 帧，比开火节奏（0.176 秒/发）略长，
## 连射时两次命中会轻微叠在一起 —— 这是要的：连中读起来是连续的"哒哒"，
## 而不是一闪一灭的孤点。
const LIFE := 0.22
## 刻线内端到中心的起始距离（px）。必须 ≥ 8 —— 准星四臂占 2~6px，
## 刻线从 2.5 起步会正好压在准星臂上，两个形状径向范围重合，读成"准星变粗了"
## 而不是"命中了"。8 起步让刻线一开始就浮在准星外侧。
const RADIUS_START := 8.0
## 刻线内端弹到的最远距离（px）。超过 16 会跑出 480x270 的注意力区。
const RADIUS_END := 14.0
## 刻线长度（px）。普通命中 4，弱点 5.5 —— 只靠颜色区分在快速移动中看不清。
const LEN_BODY := 4.0
const LEN_WEAK := 5.5
const THICK := 1.0
## 控件边长。调用方必须在 add_child 之前用它设 size —— _ready() 里设太晚，
## 调用方算居中位置时读到的还是 (0,0)。
## 46 而不是 24：刻线最远到 RADIUS_END + LEN_WEAK = 19.5px，再加 1px 暗边，
## 控件半边长必须 ≥21，否则 45° 方向的线端被自身矩形裁掉。
const BOX := Vector2(46.0, 46.0)

const COL_BODY := Color(0.97, 0.98, 0.95, 1.0)
const COL_WEAK := Color(1.0, 0.84, 0.34, 1.0)
## 1px 下沉暗边。亮背景（ch01 白石大堂）上纯白刻线会消失，没有暗边就看不见。
const COL_EDGE := Color(0.0, 0.0, 0.0, 0.45)

var _t: float = 1.0
var _weak: bool = false

func _ready() -> void:
	name = "HitMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BOX
	set_process(false)

## 由 HudWidgets.play_hit_marker 调用。重复命中会重置进度（不是叠加），
## 连射时读成"每发都重新弹一次"。
func fire(is_weakspot: bool) -> void:
	_t = 0.0
	_weak = is_weakspot
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_t = minf(_t + delta / LIFE, 1.0)
	queue_redraw()
	if _t >= 1.0:
		set_process(false)

func _draw() -> void:
	if _t >= 1.0:
		return
	# 弹开用 ease-out（前快后慢），淡出用偏快的幂次 —— 两者反向，视觉上
	# 刻线在"冲出去"的同时变淡，而不是整体像一块图在缩小。
	var ease_out: float = 1.0 - pow(1.0 - _t, 2.2)
	var radius: float = lerpf(RADIUS_START, RADIUS_END, ease_out)
	var alpha: float = 1.0 - pow(_t, 1.4)
	var tick_len: float = LEN_WEAK if _weak else LEN_BODY
	var col: Color = COL_WEAK if _weak else COL_BODY
	col.a = alpha
	var edge: Color = COL_EDGE
	edge.a = COL_EDGE.a * alpha
	var center: Vector2 = size * 0.5

	# 四条 45° 刻线（右上 / 右下 / 左下 / 左上），先画暗边再画本体。
	# 刻意不用圆环：任何环都会和准星四臂在同一个径向范围里叠成一坨，
	# 弱点只靠颜色 + 更长的刻线区分，形态保持极简。
	for i: int in 4:
		var ang: float = PI * 0.25 + PI * 0.5 * float(i)
		var dir := Vector2(cos(ang), sin(ang))
		var p0: Vector2 = center + dir * radius
		var p1: Vector2 = center + dir * (radius + tick_len)
		draw_line(p0 + Vector2(0.0, 1.0), p1 + Vector2(0.0, 1.0), edge, THICK, false)
		draw_line(p0, p1, col, THICK, false)
