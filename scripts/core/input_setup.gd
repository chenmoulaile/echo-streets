## 输入动作自举（运行时注册 InputMap）+ 操控方案切换
## class_name: InputSetup
## 挂载节点类型: 无（静态工具类，extends RefCounted，由 GameManager._ready() 调用一次）
## 依赖信号: 无
## 节点路径假设: 无
## 存在理由: 玩法脚本依赖一批输入动作，但本模块的写权限只覆盖 scripts/，
##           不能改 project.godot 的 [input] 段。因此在这里用代码补齐默认绑定：
##           项目设置里已定义的同名动作会被保留（不覆盖玩家自定义），
##           缺失的动作按下面的默认键位注册。
## 契约纪律: 动作名必须与消费方逐字一致。消费方清单（grep is_action_ / get_vector）：
##           player.gd: move_left/move_right/move_forward/move_back/jump/sprint/crouch
##                      fire/reload/weapon_1/weapon_2/weapon_3/weapon_next/weapon_prev
##           player_aim.gd: aim/bash
##           game_manager.gd: pause / settings_panel.gd: settings
## 操控方案（参考 Left 4 Dead）:
##   A = L4D 原生：左键开火 / 中键开镜 / 右键推僵僵
##   B = 经典：   左键开火 / 右键开镜 / V 键推挤
## 关键设计：物理键的分叉只落在 InputMap 上（apply_scheme 整表擦除后重绑），
##   玩法代码只认语义动作 aim / bash，永远不知道物理键是哪个 —— 零分支。
##   反例（禁止）：在 Player 里写 if scheme == A 判断右键含义。那样 A→B 切换时
##   右键会同时命中 aim 与 bash（Godot 一次按键可命中多个 action），
##   一按右键既开镜又推人。
class_name InputSetup
extends RefCounted

## 操控方案。数值写入用户设置存档。
enum Scheme { L4D = 0, CLASSIC = 1 }

## 动作名 → 键盘键位列表（全部为物理键位，兼容非 QWERTY 布局）
const _KEY_DEFAULTS: Dictionary = {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE],
	&"sprint": [KEY_SHIFT],
	&"crouch": [KEY_CTRL, KEY_C],
	&"reload": [KEY_R],
	&"weapon_1": [KEY_1],
	&"weapon_2": [KEY_2],
	&"weapon_3": [KEY_3],
	&"pause": [KEY_ESCAPE],
	&"interact": [KEY_E],
	## 设置面板。不用 KEY_S —— 那是 move_back 的第二键位，会互相吞键。
	&"settings": [KEY_O],
}

## 动作名 → 鼠标按键（射击与滚轮切枪）
const _MOUSE_DEFAULTS: Dictionary = {
	&"fire": MOUSE_BUTTON_LEFT,
	&"weapon_next": MOUSE_BUTTON_WHEEL_DOWN,
	&"weapon_prev": MOUSE_BUTTON_WHEEL_UP,
}

## 消费方要求的全部动作名（用于一致性自检，避免注册名与使用名再次漂移）
## 注意：aim / bash 不在这里 —— 它们的绑定由 apply_scheme 独占管理，
## 进了 ensure_defaults 的默认表就会被抢先注册成固定键位。
const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"sprint", &"crouch",
	&"fire", &"reload", &"weapon_1", &"weapon_2", &"weapon_3",
	&"weapon_next", &"weapon_prev", &"pause", &"settings",
]

## 方案 A（L4D 原生）：中键开镜、右键推挤
const _AIM_L4D: int = MOUSE_BUTTON_MIDDLE
const _BASH_L4D: int = MOUSE_BUTTON_RIGHT
## 方案 B（经典）：右键开镜、V 推挤
const _AIM_CLASSIC: int = MOUSE_BUTTON_RIGHT
const _BASH_CLASSIC: int = KEY_V

## 幂等：重复调用不会重复添加事件，也不会覆盖已存在的动作。
## 注意：本函数语义是"补齐缺失"，不是"重绑"。切方案必须用 apply_scheme。
static func ensure_defaults() -> void:
	for action: StringName in _KEY_DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: int in _KEY_DEFAULTS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			InputMap.action_add_event(action, event)
	for action: StringName in _MOUSE_DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var event := InputEventMouseButton.new()
		event.button_index = _MOUSE_DEFAULTS[action] as MouseButton
		InputMap.action_add_event(action, event)

## 应用操控方案。**必须整表擦除后重绑，不能追加**：
## 方案 A 的右键是 bash，方案 B 的右键是 aim —— 同一个物理键在两种方案下
## 属于不同 action。追加会让右键同时命中两者。
static func apply_scheme(scheme: int) -> void:
	var classic: bool = scheme == Scheme.CLASSIC
	_bind(&"aim", _mouse_event(_AIM_CLASSIC if classic else _AIM_L4D))
	if classic:
		_bind(&"bash", _key_event(_BASH_CLASSIC))
	else:
		_bind(&"bash", _mouse_event(_BASH_L4D))

## 单个 action 的"擦干净再绑一个"。
static func _bind(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

static func _mouse_event(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button as MouseButton
	return e

static func _key_event(key: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = key as Key
	return e

## 供自检/调试用：返回缺失的动作名列表
static func missing_actions() -> Array[StringName]:
	var missing: Array[StringName] = []
	for action: StringName in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			missing.append(action)
	for action: StringName in [&"aim", &"bash"]:
		if not InputMap.has_action(action):
			missing.append(action)
	return missing

## 供自检/调试用：返回没有绑定任何事件的已注册动作（有动作但按键为空 = 按了没反应）
static func unbound_actions() -> Array[StringName]:
	var unbound: Array[StringName] = []
	var all: Array[StringName] = REQUIRED_ACTIONS.duplicate()
	all.append(&"aim")
	all.append(&"bash")
	for action: StringName in all:
		if InputMap.has_action(action) and InputMap.action_get_events(action).is_empty():
			unbound.append(action)
	return unbound
