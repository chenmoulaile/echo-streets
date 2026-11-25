## 丧尸纸片人的表现层：帧动画驱动 + hit-flash 着色器同步。
## 挂在 zombie 场景的 Sprite3D 上。
##
## 存在理由:
##   1. material_override 会接管贴图采样，Sprite3D 自带的 flip_h 不再生效；
##      着色器有自己的 flip_h uniform，必须由本脚本镜像过去。
##   2. 丧尸原来只有一张静态贴图，走/打/挨打/死亡全无动作。本脚本按状态推进
##      逐帧贴图（assets/sprites/zombie_frames/<prefix>_<state>_<i>.png）。
##
## 为什么用逐帧换贴图而不是 AnimatedSprite3D + 图集:
##   zombie_hit_flash.gdshader 头注释已实测 —— Sprite3D 的四边形长宽比跟整张贴图走，
##   在图集里切帧会把帧横向拉伸；而本脚本每帧重绑一次 albedo_texture，UV 恒为 0..1，
##   零区域换算。逐帧贴图总字节也远小于图集（每帧只存有效像素）。
extends Sprite3D

const FLASH_DECAY := 7.0
const FRAME_DIR := "res://assets/sprites/zombie_frames/"

## 状态 -> [帧数, 帧率, 是否循环]
## run / grab 由 tmp/ZombieFrames2.py 生成（旧 5 态由同一脚本 verify 模式逐像素复现
## tmp/ZombieAnim.cs 的产物，证明移植没走样）。
##   run  6 帧 @12fps：与 walk 共用两相步态，但摆幅 14px（walk 是 6px）、抬腿 9px、
##        躯干前倾 2px。走路 ±6px 在 128px 画布上只动脚踝，看不出在跑。
##   grab 4 帧 @9fps 非循环：抬手 → 前扑 → 双手在胸前合拢钳住 → 往回拽。
##        与 attack 的区别是「合拢」：attack 张爪抓空，grab 双手越过躯干中线交叠 ——
##        正面视角下「抓住」唯一读得出的形态就是两只手合到身前。
const ANIMS := {
	&"idle": [4, 4.0, true],
	&"walk": [6, 9.0, true],
	&"run": [6, 12.0, true],
	&"attack": [3, 9.0, false],
	&"grab": [4, 9.0, false],
	&"hurt": [2, 9.0, false],
	&"death": [5, 6.0, false],
}

## 贴图前缀（如 zombie_fodder）。由 BuildWorld 写入场景时设置。
@export var frame_prefix: String = "zombie_fodder"

var _mat: ShaderMaterial
var _flash: float = 0.0
var _frames: Dictionary = {}          ## state -> Array[Texture2D]
var _anim: StringName = &"idle"
var _frame_index: int = 0
var _frame_time: float = 0.0
var _anim_done: bool = false

func _ready() -> void:
	_mat = material_override as ShaderMaterial
	_load_frames()
	_apply_frame()
	var zombie: Node = get_parent()
	if zombie == null:
		return
	var hp: Node = zombie.get_node_or_null(^"HealthComponent")
	if hp != null and hp.has_signal(&"damaged"):
		hp.connect(&"damaged", _on_damaged)

## 一次把所有状态帧读进内存。每只丧尸 20 张小图，池化后常驻，不再走磁盘。
func _load_frames() -> void:
	for state: StringName in ANIMS:
		var list: Array[Texture2D] = []
		var count: int = ANIMS[state][0]
		for i: int in count:
			var path: String = FRAME_DIR + frame_prefix + "_" + String(state) + "_" + str(i) + ".png"
			if ResourceLoader.exists(path):
				list.append(load(path) as Texture2D)
		if not list.is_empty():
			_frames[state] = list

## 切动画。同一状态重复调用不重置（避免每帧重启 idle 卡在第 0 帧）。
func play(state: StringName, restart: bool = false) -> void:
	if not _frames.has(state):
		return
	if _anim == state and not restart:
		return
	_anim = state
	_frame_index = 0
	_frame_time = 0.0
	_anim_done = false
	_apply_frame()

func is_anim_done() -> bool:
	return _anim_done

func current_anim() -> StringName:
	return _anim

func _on_damaged(_amount: float, _is_fatal: bool, _source: Node) -> void:
	_flash = 1.0

func _process(delta: float) -> void:
	_tick_anim(delta)
	if _mat == null:
		return
	_mat.set_shader_parameter(&"flip_h", flip_h)
	if _flash > 0.0:
		_flash = maxf(_flash - delta * FLASH_DECAY, 0.0)
		_mat.set_shader_parameter(&"flash_amount", _flash)

func _tick_anim(delta: float) -> void:
	if not _frames.has(_anim):
		return
	var cfg: Array = ANIMS[_anim]
	var count: int = (_frames[_anim] as Array).size()
	var fps: float = cfg[1]
	var looping: bool = cfg[2]
	if _anim_done:
		return
	_frame_time += delta
	var step: float = 1.0 / maxf(fps, 0.001)
	while _frame_time >= step:
		_frame_time -= step
		_frame_index += 1
		if _frame_index >= count:
			if looping:
				_frame_index = 0
			else:
				_frame_index = count - 1
				_anim_done = true
				break
		_apply_frame()

func _apply_frame() -> void:
	var list: Array = _frames.get(_anim, []) as Array
	if list.is_empty():
		return
	_frame_index = clampi(_frame_index, 0, list.size() - 1)
	texture = list[_frame_index] as Texture2D
	# 每帧重绑：着色器的 albedo_texture 是 uniform，换贴图不会自动跟着换
	if _mat != null:
		_mat.set_shader_parameter(&"albedo_texture", texture)
		_mat.set_shader_parameter(&"sprite_size", Vector2(texture.get_width(), texture.get_height()))
