## 游戏设置持久化（鼠标灵敏度 / 操控方案 / 音量等）。
## 挂载节点类型: 无（extends RefCounted，全部 static，**不注册 autoload**）
## 为什么不并进 GameManager 的存档：
##   `GameManager.complete_level()` 会整体重写关卡存档（chapter / kills / health），
##   设置混进去就会每次通关被冲掉。设置是"跨存档的玩家偏好"，
##   生命周期比一局游戏长，必须独立文件。
## 为什么不用 autoload：
##   全 static + 一个 JSON 文件，没有任何需要 _process/_ready 的状态。
##   加 autoload 只会在启动顺序上多一个不确定项（读写时机 vs InputSetup 注册）。
## 容错原则：读失败一律回默认值，不阻塞启动 —— 设置坏掉不该让游戏进不去。
class_name GameSettings
extends RefCounted

const PATH := "user://settings_echo_streets.json"
## 设置版本。字段增删时升级，读到旧版本按键名取值（缺的走默认）。
const VERSION := 1

# ── 默认值（唯一事实来源，面板与读取都从这里取）──────────────────
## 鼠标灵敏度倍率。1.0 = 基准 0.0022 rad/px。
const DEFAULT_SENSITIVITY := 1.0
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 3.0
## 操控方案：0 = L4D（左火/中镜/右推），1 = 经典（左火/右镜/V推）
const DEFAULT_SCHEME := 0
const SCHEME_L4D := 0
const SCHEME_CLASSIC := 1
## 主音量（0~1）
const DEFAULT_VOLUME := 1.0

## 当前内存中的设置。启动时 GameManager 调一次 load() 填充。
static var sensitivity: float = DEFAULT_SENSITIVITY
static var scheme: int = DEFAULT_SCHEME
static var volume: float = DEFAULT_VOLUME
## 是否已从磁盘读过。避免每次取设置都读盘。
static var _loaded: bool = false

## 读盘并应用到内存。返回是否成功读到文件（false = 用默认值）。
static func load_settings() -> bool:
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return false
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("GameSettings: 打开失败 %s（错误码 %d）" % [PATH, FileAccess.get_open_error()])
		return false
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("GameSettings: 设置 JSON 解析失败，已回默认。")
		return false
	var d: Dictionary = parsed
	sensitivity = clampf(float(d.get("sensitivity", DEFAULT_SENSITIVITY)),
		SENSITIVITY_MIN, SENSITIVITY_MAX)
	scheme = clampi(int(d.get("scheme", DEFAULT_SCHEME)), SCHEME_L4D, SCHEME_CLASSIC)
	volume = clampf(float(d.get("volume", DEFAULT_VOLUME)), 0.0, 1.0)
	return true

## 确保内存里有一份可用设置。任何读设置的入口先调它。
static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()

static func save_settings() -> bool:
	var d: Dictionary = {
		"version": VERSION,
		"sensitivity": sensitivity,
		"scheme": scheme,
		"volume": volume,
	}
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("GameSettings: 写入失败 %s（错误码 %d）" % [PATH, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true

## 设置灵敏度（钳制 + 立即落盘）。面板改一次存一次，不做"应用"按钮。
## 必须发 settings_changed：Player 只在 _ready 读一次 sensitivity_scale，
## 不推信号的话拖完滑条要重进关卡才生效 —— 用户会以为滑条坏了。
static func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	save_settings()
	EventBus.settings_changed.emit()

static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()
	EventBus.settings_changed.emit()

## 把 volume 落到 Master 总线。linear_to_db(0) 是 -inf，必须给下限，
## 否则滑到 0 时 set_bus_volume_db 收到 -inf 会让整条总线静音到不可恢复。
static func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(volume, 0.0001, 1.0)))

## 设置操控方案并立刻重绑物理键（InputSetup.apply_scheme 是幂等的整表重绑）。
static func set_scheme(value: int) -> void:
	scheme = clampi(value, SCHEME_L4D, SCHEME_CLASSIC)
	InputSetup.apply_scheme(scheme)
	EventBus.input_scheme_changed.emit(scheme)
	save_settings()

## 启动时应用一次（把持久化的方案真正绑到 InputMap 上）。
static func apply_all() -> void:
	ensure_loaded()
	InputSetup.apply_scheme(scheme)
	apply_volume()

static func scheme_name(value: int) -> String:
	return "经典（右键开镜 / V 推挤）" if value == SCHEME_CLASSIC else "求生之路（中键开镜 / 右键推挤）"
