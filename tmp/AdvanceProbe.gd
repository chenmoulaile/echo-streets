## 换章实跑探针 —— 逻辑本体。
## 由 tmp/AdvanceFlow.gd 在 _ready 里动态 new 出来挂到 get_tree().root，
## 因此 reload_current_scene() 换掉 current_scene 时不会被一起释放。
extends Node

const MAIN := "res://scenes/main.tscn"

var _fail: int = 0
var _pass: int = 0

## 入口。启动器不 await 本协程 —— 启动器所在的 current_scene 会被换掉，
## 挂在上面的协程一起销毁。收尾必须在本节点（挂在 root 下）自己完成。
## 由本节点自己的 _ready 触发：启动器用 add_child.call_deferred 挂进来，
## 那时 root 已经脱离 "_ready 期间不可加子节点" 的忙状态。
func _ready() -> void:
	start()

func start() -> void:
	await run()
	print("=== ADVANCE pass=%d fail=%d ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", what)

## 等 current_scene 变成一个 chapter_data 已就绪的 Level。最多等 180 帧。
func _wait_scene() -> Node:
	for _i: int in 180:
		if not is_inside_tree():
			return null
		await get_tree().process_frame
		var cs: Node = get_tree().current_scene
		if cs != null and cs.has_method(&"chapter_data"):
			if cs.call(&"chapter_data") != null:
				return cs
	return null

func _chapter_id(level: Node) -> String:
	if level == null:
		return "<null>"
	var d: Variant = level.call(&"chapter_data")
	if d == null:
		return "<no-data>"
	return String(d.get("id"))

func run() -> void:
	GameManager.set_chapter(0)
	get_tree().change_scene_to_file(MAIN)
	var level: Node = await _wait_scene()
	_check(level != null, "第一章场景未就绪")
	if level == null:
		return
	await get_tree().create_timer(0.5).timeout
	_check(_chapter_id(level) == "chapter_01", "第一章 id 应为 chapter_01，实际 %s" % _chapter_id(level))
	_check(GameManager.state() == GameManager.GameState.PLAYING, "第一章应处于 PLAYING")

	# 触发通关信号 → GameManager._on_all_waves_cleared 应自动进第二章
	EventBus.all_waves_cleared.emit()
	level = await _wait_scene()
	_check(level != null, "换章后场景未就绪")
	if level == null:
		return
	await get_tree().create_timer(0.5).timeout
	_check(_chapter_id(level) == "chapter_02", "换章后 id 应为 chapter_02，实际 %s" % _chapter_id(level))
	_check(GameManager.chapter_index() == 1, "chapter_index 应为 1，实际 %d" % GameManager.chapter_index())
	_check(GameManager.state() == GameManager.GameState.PLAYING, "第二章应处于 PLAYING")
	_check(is_equal_approx(Engine.time_scale, 1.0), "换章后 time_scale 应复位为 1.0")
	_check(get_tree().paused == false, "换章后不应处于暂停")

	EventBus.all_waves_cleared.emit()
	level = await _wait_scene()
	await get_tree().create_timer(0.5).timeout
	_check(_chapter_id(level) == "chapter_03", "第三章 id 应为 chapter_03，实际 %s" % _chapter_id(level))

	# 跳到末章再触发 → 应判定 demo 通关，且不再换场景
	GameManager.set_chapter(3)
	get_tree().change_scene_to_file(MAIN)
	level = await _wait_scene()
	await get_tree().create_timer(0.5).timeout
	_check(_chapter_id(level) == "chapter_04", "末章 id 应为 chapter_04，实际 %s" % _chapter_id(level))
	EventBus.all_waves_cleared.emit()
	await get_tree().create_timer(0.4).timeout
	_check(GameManager.state() == GameManager.GameState.LEVEL_COMPLETE,
		"末章清空后应进入 LEVEL_COMPLETE，实际 %d" % int(GameManager.state()))
	_check(_chapter_id(get_tree().current_scene) == "chapter_04", "末章清空后不应再换场景")

	# 末章按 R 应回到第一章
	GameManager.restart_demo()
	level = await _wait_scene()
	await get_tree().create_timer(0.5).timeout
	_check(_chapter_id(level) == "chapter_01", "restart_demo 后应回到 chapter_01，实际 %s" % _chapter_id(level))
