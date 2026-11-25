extends Node
## 存档往返验证：save_game → 改内存状态 → load_game 读回，逐字段比对。
## 只验证 SaveIO + GameManager 的存档契约，不碰场景/关卡。

func _ready() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var gm: Node = get_node_or_null(^"/root/GameManager")
	if gm == null:
		print("=== SAVE FAIL no GameManager ===")
		get_tree().quit(1)
		return

	var passed: int = 0
	var failed: int = 0

	# 1) 初始状态：先写一次，确认 write 返回 true
	var ok: bool = gm.call(&"save_game")
	if ok:
		passed += 1
		print("[ok] save_game 返回 true")
	else:
		failed += 1
		print("[FAIL] save_game 返回 false")

	# 2) has_save 应为真
	if gm.call(&"has_save"):
		passed += 1
		print("[ok] has_save 为真")
	else:
		failed += 1
		print("[FAIL] has_save 为假")

	# 3) 读回，逐字段校验
	var data: Dictionary = gm.call(&"load_game")
	var need: Array = ["version", "chapter_index", "chapter_total",
		"level_index", "kill_count", "player_health", "saved_at"]
	for k: String in need:
		if data.has(k):
			passed += 1
			print("[ok] 字段 %s = %s" % [k, str(data[k])])
		else:
			failed += 1
			print("[FAIL] 缺字段 %s" % k)

	# 4) version 必须是 2（格式演进锚点）
	if int(data.get("version", -1)) == 2:
		passed += 1
		print("[ok] version == 2")
	else:
		failed += 1
		print("[FAIL] version 不是 2")

	# 5) chapter_total 必须等于 Chapters.count()（防存档写死旧章数）
	var Chapters: GDScript = load("res://scripts/level/chapters.gd")
	if int(data.get("chapter_total", -1)) == Chapters.count():
		passed += 1
		print("[ok] chapter_total == %d" % Chapters.count())
	else:
		failed += 1
		print("[FAIL] chapter_total %d != %d"
			% [int(data.get("chapter_total", -1)), Chapters.count()])

	# 6) 换章后写档，再读回，chapter_index 必须跟着变
	gm.call(&"set_chapter", 2)
	gm.call(&"save_game")
	var d2: Dictionary = gm.call(&"load_game")
	if int(d2.get("chapter_index", -1)) == 2:
		passed += 1
		print("[ok] 换章后 chapter_index == 2")
	else:
		failed += 1
		print("[FAIL] 换章后 chapter_index = %d" % int(d2.get("chapter_index", -1)))

	# 7) 存档文件确实是合法 JSON 文本（不是二进制/空文件）
	var f: FileAccess = FileAccess.open("user://save_echo_streets.json", FileAccess.READ)
	if f != null:
		var text: String = f.get_as_text()
		f.close()
		if text.length() > 2 and text.begins_with("{"):
			passed += 1
			print("[ok] 存档是 JSON 文本 len=%d" % text.length())
		else:
			failed += 1
			print("[FAIL] 存档不是 JSON 文本 len=%d" % text.length())
	else:
		failed += 1
		print("[FAIL] 存档文件打不开")

	# 复位，别把测试状态留给后面
	gm.call(&"set_chapter", 0)
	gm.call(&"save_game")

	print("=== SAVE pass=%d fail=%d ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
