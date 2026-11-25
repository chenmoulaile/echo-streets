## 第一人称武器视图模型（viewmodel）：逐帧动画状态机 + 后坐位移 + 开镜位移 + 枪口定位。
## class_name: Viewmodel
## 挂载节点类型: TextureRect（由 HudWidgets 创建并加为子节点）
## 素材来源: assets/sprites/viewmodel/ —— 两条管线并存：
##   手枪 → tmp/VmUser.py，母图是**用户自己生图产出**的 D:\mygame\vm_pistol_idle.png
##          （1248x512 洋红底，单手持枪、枪管指向左上）。223x188，24 色。
##          **不要再用参考帧几何覆盖它** —— 用户明确要求手枪用他生成的那张。
##          动作帧靠**绕握把旋转**合成（枪口下压/上跳），不是整张图平移：
##          纯平移在实机读成"枪掉下去了"，用户明确否过。
##   霰弹枪 → tmp/VmRebuild.py + tmp/VmFrames3.py，几何沿用参考帧
##          （tmp/fp_png/Shotgun__ShotgunIdle.png 464x275），只换材质与配色：
##            1) 藏青手套 → 裸手肤色（明度 24/38/58/84 四档映射，保留体积分层）
##            2) 中性灰枪身 → 深蓝灰自研配色（保明度排序，只换色相/饱和度）
##          259x150，动作帧是整数像素平移。
##   手枪换弹不画外挂弹匣：手枪弹匣在握把内，画一个外挂方块是错的。
## 透视铁律（这是"视角正确"的判据，别再走错）：
##   参考帧是「枪管指向屏幕深处」的**强透视压缩**视角：枪身 bbox 112x250，
##   高宽比 2.23，看到的是套筒**顶面与背面**，枪口在远处变小。
##   早期版本的错误：拿 AI 生成的**纯侧视剖面**（高宽比 0.98）旋转 70 度硬凑
##   「枪管竖直」—— 侧视图没有顶面，旋转只能得到一张转来转去的侧视图，
##   于是枪管看起来「朝天花板」。判据不是角度数值，而是**有没有顶面透视**。
## 开镜（ADS）为什么只平移不缩放：
##   TextureRect 只能整数像素平移，缩放会让 NEAREST 采样丢整行/整列像素，
##   枪身出现断裂。所以开镜表现 = 整体平移到瞄准姿态 + 准星淡出，由 HUD 侧配合。
## 设计约束（PDF）:
##   - 逻辑分辨率 480x270，坐标直接按 480x270 写。
##   - texture_filter = NEAREST，禁止抗锯齿。
##   - 单文件不超过 300 行。
## 为什么不用 AnimatedSprite2D：viewmodel 需要按"状态 + 剩余时间"精确插值帧
##   （换弹 1.35s 要铺满 4 帧、开火 0.24s 要播完 3 帧），AnimatedSprite2D 的
##   固定 fps 播放对不上不同武器的节奏，且无法在换弹中途被打断后复位。
class_name Viewmodel
extends TextureRect

const DIR := "res://assets/sprites/viewmodel/"
## 开火帧序列的每帧停留时长（秒）。低于 0.03 在 60 帧下会跳过中间帧。
const FIRE_FRAME_TIME := 0.045
## 拔枪动画时长
const DRAW_TIME := 0.22
## 后坐位移衰减速度（像素/秒）
const KICK_RECOVER := 42.0
## 开镜时 viewmodel 的整像素位移。TextureRect 不能旋转（像素图旋转会撕裂），
## 只能整体平移：向左把枪身往画面中轴收（手枪 228 → 208，枪口 57.6% → 53.5%），
## 向下把枪口压到准星水平线附近，读成"举枪贴腮"。
## 左移量取 20px（实测上限 30px）：再大开镜瞬间枪身会横移一大段，
## 读成"甩枪"而不是举枪；20px 对应开镜后中心区占用 11.3% → 25.7%。
## 注意这个左移是**开镜专用**：腰射时枪必须偏右（见下面 PISTOL 的落位说明），
## 开镜才收回来 —— 两者混用会让腰射状态也压在中轴上。
## 共用副作用：这个常量两把枪共用。手枪 pos.x 从 206 右移到 228 之后，霰弹枪的
##   开镜位置也跟着从 144 变成 138（枪口 49.6% → 48.3%，中心区 36.4% → 39.7%）。
##   方向是一致的（开镜都比腰射更居中），霰弹枪腰射落位 158 未动，
##   用户没抱怨过霰弹枪挡视野，所以不为此单独拆常量（拆了要多一个字段 + 分支）。
const ADS_SHIFT := Vector2(-20.0, 10.0)
## 开镜位移的逼近速度（混合量/秒）。8.0 ≈ 0.125 秒到位，与 player_aim.gd 的
## ADS_TIME（0.12）同量级，枪身与 FOV 同步收拢。
const ADS_BLEND_SPEED := 8.0

## 每把武器的贴图布局。pos 是 TextureRect 在 480x270 逻辑屏上的左上角，
## muzzle 是枪口在该贴图内的像素坐标（VmUser.py / VmFrames3.py 打印，不要手量）。
## 落位原则：贴图**底边与屏幕底边齐平**（pos.y = 270 - 贴图高），前臂由屏幕底边出画。
##
## 横向落位（用户 m11558：不要把枪械和手臂放在视角正中央，参考 BOOM 的主武器；
##   后续复核：照抄 BOOM 的 53.5% 实机仍挡中间视野，所以**不能对齐参考值，要继续右移**）：
##   基准量的是 BOOM `Shotgun__ShotgunIdle.png`（主武器）归一化到 480x270 的结果 ——
##   枪口 x = 53.5%（偏右 3.5%）、中心区占用率（x[40-60%] y[35-75%] 的像素面积占比）
##   = 21.6%。用户明确说**不要参考 BOOM 的手枪**，因为手枪枪口在 47.8%（居中）。
##   实测扫描（贴图 229x188、pos.y=82、脚本 tmp/_vmpos.py，可重跑）：
##     pos.x 206 → 枪口 53.0% 中心区 27.0% 右边界 80.0%
##     pos.x 216 → 枪口 55.1% 中心区 20.2% 右边界 82.1%
##     pos.x 222 → 枪口 56.4% 中心区 15.9% 右边界 83.3%
##     pos.x 228 → 枪口 57.6% 中心区 11.3% 右边界 84.6%   ← 取这个
##     pos.x 234 → 枪口 58.9% 中心区  6.4% 右边界 85.8%
##     pos.x 240 → 枪口 60.1% 中心区  2.7% 右边界 87.1%
##   为什么是 228：枪口 57.6% 落在 57~60% 目标带的中段（再往右枪会顶到画面右缘，
##   准星左侧的枪身占比过低，读成"枪飘出去了"）；中心区占用从 27.0% 砍到 11.3%，
##   用户抱怨的"挡住中间视野"直接消失；右边界 84.6% 仍留 15% 屏宽余量，
##   不贴死右边缘（贴死会看起来像断臂）。我们这张图手臂质量占枪身 36.9%
##   （BOOM 主武器只有 0.4%），中心区占用不可能压到 BOOM 同值 —— 能对齐的只有
##   "枪口偏右"这件事本身，不能对齐具体百分比。
## 纵向：82 + 188 = 270，底边与屏幕底边齐平；枪口落在 (276.6, 114)，
##   高于准星中心（240,135）21px，照参考帧对齐（参考帧枪口在画幅 42% 高度、准星 50%）。
const PISTOL := {
	"idle": ["vm_pistol_idle.png"],
	"fire": ["vm_pistol_fire1.png", "vm_pistol_fire2.png", "vm_pistol_fire3.png"],
	"reload": ["vm_pistol_reload1.png", "vm_pistol_reload2.png",
		"vm_pistol_reload3.png", "vm_pistol_reload4.png"],
	"draw": ["vm_pistol_draw.png"],
	"dry": "vm_pistol_dry.png",
	"size": Vector2(229.0, 188.0),
	"pos": Vector2(228.0, 82.0),
	"muzzle": Vector2(48.6, 32.0),
}
const SHOTGUN := {
	"idle": ["vm_shotgun_idle.png"],
	"fire": ["vm_shotgun_fire1.png", "vm_shotgun_fire2.png", "vm_shotgun_fire3.png",
		"vm_shotgun_fire4.png", "vm_shotgun_fire5.png"],
	"reload": ["vm_shotgun_reload1.png", "vm_shotgun_reload2.png"],
	"draw": ["vm_shotgun_draw.png"],
	"dry": "vm_shotgun_idle.png",
	"size": Vector2(259.0, 150.0),
	# 与手枪同一口径：枪口对齐 BOOM 主武器的 53.5%。实测扫描（贴图 259x150、
	# pos.y=120）：x=121 → 枪口 45.7%（压中轴，就是用户否掉的那种）、
	# x=150 → 51.8%、x=158 → 53.4%。取 158，中心区占用 18.6%。
	"pos": Vector2(158.0, 120.0),
	"muzzle": Vector2(93.9, 0.0),
}

enum State { IDLE, FIRE, RELOAD, DRAW }

var _config: Dictionary = PISTOL
var _state: State = State.IDLE
var _textures: Dictionary = {}
var _fire_index: int = 0
var _fire_left: float = 0.0
var _draw_left: float = 0.0
var _reload_total: float = 1.0
var _reload_left: float = 0.0
var _kick: float = 0.0
var _rest_pos: Vector2 = Vector2.ZERO
var _muzzle_local: Vector2 = Vector2.ZERO
## 开镜混合量 0..1。0 = 腰射姿态，1 = 完全贴到瞄准姿态。
var _ads_blend: float = 0.0
## 开镜混合的目标值。由 set_aiming() 写，_process 里以 ADS_BLEND_SPEED 逼近。
var _ads_target: float = 0.0

func _ready() -> void:
	name = "Viewmodel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_config(PISTOL)

# ── 配置装载 ────────────────────────────────────────────────────

func _apply_config(cfg: Dictionary) -> void:
	_config = cfg
	_textures.clear()
	for key: String in ["idle", "fire", "reload", "draw"]:
		var list: Array = []
		for file_name: String in cfg[key]:
			list.append(_tex(file_name))
		_textures[key] = list
	_textures["dry"] = _tex(cfg["dry"])
	size = cfg["size"]
	_rest_pos = cfg["pos"]
	position = _rest_pos
	_muzzle_local = cfg["muzzle"]
	_state = State.IDLE
	texture = (_textures["idle"] as Array)[0]

func _tex(file_name: String) -> Texture2D:
	var path := DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("[viewmodel] 缺少贴图 %s" % path)
	return null

# ── 状态驱动 ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, KICK_RECOVER * delta)
	_ads_blend = move_toward(_ads_blend, _ads_target, ADS_BLEND_SPEED * delta)
	position = _rest_pos + ADS_SHIFT * _ads_blend + Vector2(0.0, _kick)
	match _state:
		State.FIRE:
			_tick_fire(delta)
		State.DRAW:
			_draw_left = maxf(_draw_left - delta, 0.0)
			if _draw_left <= 0.0:
				_state = State.IDLE
				texture = (_textures["idle"] as Array)[0]
		State.RELOAD:
			_tick_reload(delta)
		_:
			pass

func _tick_fire(delta: float) -> void:
	_fire_left = maxf(_fire_left - delta, 0.0)
	if _fire_left > 0.0:
		return
	var frames: Array = _textures["fire"]
	_fire_index += 1
	if _fire_index >= frames.size():
		_state = State.IDLE
		texture = (_textures["idle"] as Array)[0]
		return
	texture = frames[_fire_index]
	_fire_left = FIRE_FRAME_TIME

func _tick_reload(delta: float) -> void:
	_reload_left = maxf(_reload_left - delta, 0.0)
	var frames: Array = _textures["reload"]
	if frames.is_empty():
		return
	var ratio: float = 0.0
	if _reload_total > 0.0:
		ratio = clampf(1.0 - _reload_left / _reload_total, 0.0, 1.0)
	# 帧数 - 1 段：ratio=1 时停到最后一帧，不会越界
	var idx: int = mini(int(ratio * float(frames.size())), frames.size() - 1)
	texture = frames[idx]
	if _reload_left <= 0.0:
		_state = State.IDLE
		texture = (_textures["idle"] as Array)[0]

# ── 外部接口（由 HudWidgets 调用）────────────────────────────────

## 切枪：重新装载贴图与落位，并播一次拔枪动画。
## 开镜混合量保持当前值 —— 开镜中切枪，新枪立刻就是开镜姿态，不会先跳回腰射。
func set_weapon(is_shotgun: bool) -> void:
	_apply_config(SHOTGUN if is_shotgun else PISTOL)
	_state = State.DRAW
	_draw_left = DRAW_TIME
	texture = (_textures["draw"] as Array)[0]

## 开镜开关。只写目标值，实际位移在 _process 里平滑逼近。
func set_aiming(on: bool) -> void:
	_ads_target = 1.0 if on else 0.0

func is_aiming() -> bool:
	return _ads_target > 0.5

## 开火：立刻切到第一张开火帧，并按 FIRE_FRAME_TIME 向后推进
func play_fire() -> void:
	_kick = 3.0
	_fire_index = 0
	_state = State.FIRE
	_fire_left = FIRE_FRAME_TIME
	var frames: Array = _textures["fire"]
	if not frames.is_empty():
		texture = frames[0]

## 空仓：换成"空仓"帧（手枪有专门的空仓姿势）
func play_dry() -> void:
	_state = State.IDLE
	var dry_tex: Texture2D = _textures["dry"]
	if dry_tex != null:
		texture = dry_tex

func begin_reload(duration: float) -> void:
	_state = State.RELOAD
	_reload_total = maxf(duration, 0.05)
	_reload_left = _reload_total
	var frames: Array = _textures["reload"]
	if not frames.is_empty():
		texture = frames[0]

func end_reload() -> void:
	_state = State.IDLE
	texture = (_textures["idle"] as Array)[0]

## 枪口在 HUD 逻辑坐标里的位置。
## 必须同时叠加后坐（_kick）与开镜位移（ADS_SHIFT * _ads_blend），
## 少任一项都会让火光与枪口脱节。
func muzzle_position() -> Vector2:
	return _rest_pos + ADS_SHIFT * _ads_blend + _muzzle_local + Vector2(0.0, _kick)

func current_weapon_is_shotgun() -> bool:
	return _config == SHOTGUN
