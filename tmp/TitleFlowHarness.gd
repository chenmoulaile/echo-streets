## 标题屏 → 主关卡 的切场景链路验证（常驻 root 的验证机）。
## 为什么必须常驻 root：change_scene_to_file 释放的是 current_scene，
## 验证机若挂在被切掉的场景里，协程会随节点一起消失，get_tree() 返回 null，
## 报 `Invalid access to property or key 'root' on a base object of type
## 'null instance'`，进程挂死不退出（踩过三次）。
##
## 覆盖的四个环节，都是「headless 冒烟看不出来、但玩家一定会撞上」的：
##   1. title.tscn 能实例化，SettingsPanel 挂在它下面且初始关闭
##   2. 面板 open/close 与 GameManager.ui_modal 的联动（ESC 穿透守卫）
##   3. EventBus.run_started 能发出并被接收（教程推进器靠它判断新一局）
##   4. 点 START 之后 current_scene 真的变成 Main，且五个契约节点齐全
extends Node

var _pass: int = 0
var _fail: int = 0
var _title: Node = null

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame

	# ── 1) 标题场景 ──
	var packed: PackedScene = load("res://scenes/title.tscn") as PackedScene
	_check(packed != null, "title.tscn 可加载")
	if packed == null:
		_finish()
		return
	_title = packed.instantiate()
	get_tree().root.add_child(_title)
	await get_tree().process_frame
	_check(_title.has_node(^"SettingsPanel"), "Title 下挂了 SettingsPanel")

	# ── 2) 设置面板与 ui_modal ──
	var panel: Node = _title.get_node_or_null(^"SettingsPanel")
	_check(panel != null and panel.call(&"is_open") == false, "SettingsPanel 初始为关闭")
	if panel != null:
		panel.call(&"open")
		_check(panel.call(&"is_open") == true, "open() 后 is_open() 为真")
		_check(GameManager.ui_modal == true, "面板打开时 ui_modal 为真")
		panel.call(&"close")
		_check(GameManager.ui_modal == false, "面板关闭时 ui_modal 复位")

	# ── 3) run_started ──
	var got: Array = [0]
	var cb := func() -> void: got[0] += 1
	EventBus.run_started.connect(cb)
	EventBus.run_started.emit()
	EventBus.run_started.disconnect(cb)
	_check(got[0] == 1, "run_started 可发出并被接收")

	# ── 4) 点 START 切场景 ──
	# 注意：_title 不是 current_scene（current_scene 是 runner 场景本身），
	# 所以这里调 change_scene_to_file 只会换掉 current_scene，本节点不受影响。
	_title.call(&"_on_start")
	for i in range(8):
		await get_tree().process_frame

	var cur: Node = get_tree().current_scene
	_check(cur != null, "切场景后 current_scene 非空")
	if cur != null:
		_check(cur.name == StringName("Main"), "current_scene 是 Main（实际 %s）" % cur.name)
		_check(cur.has_node(^"Player"), "Main 下有 Player")
		_check(cur.has_node(^"WaveSpawner"), "Main 下有 WaveSpawner")
		_check(cur.has_node(^"Director"), "Main 下有 Director")
		_check(cur.has_node(^"PostFX"), "Main 下有 PostFX")
		_check(cur.has_node(^"Hud"), "Main 下有 Hud")
		_check(cur.has_node(^"TutorialFlow"), "Main 下有 TutorialFlow")
		_check(cur.has_node(^"SettingsPanel"), "Main 下有 SettingsPanel")
		# 关卡起来之后必须处于 PLAYING，否则玩家进去是暂停的
		_check(GameManager.state() == GameManager.GameState.PLAYING,
			"切场景后 GameState 是 PLAYING")

	_finish()

func _finish() -> void:
	print("=== RESULT pass=%d fail=%d ===" % [_pass, _fail])
	get_tree().quit()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("[PASS] " + label)
	else:
		_fail += 1
		print("[FAIL] " + label)
