## 第一人称武器视图模型（viewmodel）：逐帧动画状态机 + 后坐位移 + 开镜位移 + 枪口定位。
## class_name: Viewmodel
## 挂载节点类型: TextureRect（由 HudWidgets 创建并加为子节点）
## 素材来源: assets/sprites/viewmodel/ —— 管线 tmp/VmRebuild.py + tmp/VmFrames3.py。
##   **几何直接沿用参考帧**（tmp/fp_png/Handgun__HandgunIdle.png 245x262、
##   Shotgun__ShotgunIdle.png 464x275），只换材质与配色：
##     1) 藏青手套 → 裸手肤色（按明度 24/38/58/84 四档映射，保留原有体积分层）
##     2) 中性灰枪身 → 深蓝灰自研配色（保明度排序，只换色相/饱和度）
##   手枪 146x150、霰弹枪 259x150。
##   动作帧用**整数像素平移**合成 —— 像素画旋转会产生锯齿断线。
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
## 只能整体平移：向左把枪身推回画面中轴（手枪 183 → 169，中轴 167），
## 向下把枪口压到准星水平线附近，读成"举枪贴腮"。
const ADS_SHIFT := Vector2(-14.0, 10.0)
## 开镜位移的逼近速度（混合量/秒）。8.0 ≈ 0.125 秒到位，与 player_aim.gd 的
## ADS_TIME（0.12）同量级，枪身与 FOV 同步收拢。
const ADS_BLEND_SPEED := 8.0

## 每把武器的贴图布局。pos 是 TextureRect 在 480x270 逻辑屏上的左上角，
## muzzle 是枪口在该贴图内的像素坐标（VmFrames3.py 打印，不要手量）。
## 落位原则：贴图**底边与屏幕底边齐平**（pos.y = 270 - 贴图高），前臂由屏幕底边
## 出画；水平让枪身落在画面中轴附近（参考帧实测手枪 cx 55%、霰弹枪 59%）。
const PISTOL := {
	"idle": ["vm_pistol_idle.png"],
	"fire": ["vm_pistol_fire1.png", "vm_pistol_fire2.png", "vm_pistol_fire3.png"],
	"reload": ["vm_pistol_reload1.png", "vm_pistol_reload2.png",
		"vm_pistol_reload3.png", "vm_pistol_reload4.png"],
	"draw": ["vm_pistol_draw.png"],
	"dry": "vm_pistol_dry.png",
	"size": Vector2(146.0, 150.0),
	"pos": Vector2(183.0, 120.0),
	"muzzle": Vector2(38.1, 0.0),
}
const SHOTGUN := {
	"idle": ["vm_shotgun_idle.png"],
	"fire": ["vm_shotgun_fire1.png", "vm_shotgun_fire2.png", "vm_shotgun_fire3.png",
		"vm_shotgun_fire4.png", "vm_shotgun_fire5.png"],
	"reload": ["vm_shotgun_reload1.png", "vm_shotgun_reload2.png"],
	"draw": ["vm_shotgun_draw.png"],
	"dry": "vm_shotgun_idle.png",
	"size": Vector2(259.0, 150.0),
	"pos": Vector2(121.0, 120.0),
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
