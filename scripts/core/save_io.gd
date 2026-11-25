## 存档 IO 层：JSON 序列化 / 反序列化 / 存在性检查。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   game_manager.gd 在补齐章节推进与存档后涨到 302 行，超红线。
##   职责切分：game_manager 管"运行时状态机"（BOOT/PLAYING/PAUSED/DEAD/CLEARED、
##   慢动作、击杀计数、章节推进），本文件管"状态的持久化格式"。
##   存档格式是会随版本演进的（payload 里带 version 字段），
##   独立成文件后改格式不用动状态机，也不会撞行数红线。
## 与 PDF 的对应:
##   "存档 JSON 序列化到 user://，每关通关节点自动存档"。
## path 参数化（向后兼容）:
##   关卡进度与用户设置必须分文件存 —— game_manager.complete_level() 会整体
##   重写关卡存档，设置混进去会被每次通关冲掉。默认参数保证既有调用零改动。
extends RefCounted

const SAVE_PATH: String = "user://save_echo_streets.json"

## 写存档。payload 由调用方组装（本层不关心字段语义）。
## 返回 false 表示打开失败（权限/磁盘），错误已 push_error。
static func write(payload: Dictionary, path: String = SAVE_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveIO: 存档打开失败 %s（错误码 %d）"
			% [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

## 读存档。文件不存在或 JSON 损坏时返回空字典，不抛异常。
static func read(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("SaveIO: 存档 JSON 解析失败，已忽略。")
	return {}

static func exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)
