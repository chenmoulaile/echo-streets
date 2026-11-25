## 临时验证：处决慢动作时序（不属于交付物）
## 专测旧骨架硬伤 6 —— create_timer 受 Engine.time_scale 二次缩放。
## 断言：0.5 秒请求在 0.25 倍速下，墙钟恢复时间必须落在 0.4~0.75 秒区间，
##       而不是被二次缩放到 2 秒。
extends Node

var _errors: Array[String] = []

func _ready() -> void:
	print("=== SLOWMO TEST START ===")
	await _test_slowmo_timing()
	await _test_slowmo_no_stack()
	await _test_slowmo_clamp()
	await _test_state_machine()
	_report()

func _test_slowmo_timing() -> void:
	Engine.time_scale = 1.0
	var start: int = Time.get_ticks_msec()
	GameManager.request_slowmo(0.5)
	# 请求后立刻检查：时间缩放已降至 0.25（PDF 规定值）
	_check(is_equal_approx(Engine.time_scale, GameManager.SLOWMO_SCALE),
		"慢动作生效 Engine.time_scale == 0.25（实际 %.2f）" % Engine.time_scale)
	# 用 ignore_time_scale 的计时器等墙钟 0.9 秒，足够覆盖 0.5 秒恢复
	await get_tree().create_timer(0.9, true, false, true).timeout
	var elapsed: int = Time.get_ticks_msec() - start
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"慢动作已恢复 Engine.time_scale == 1.0（实际 %.2f）" % Engine.time_scale)
	_check(elapsed < 1500,
		"墙钟恢复耗时未二次缩放（实际 %d ms，上限 1500）" % elapsed)
	_check(not GameManager.is_slowmo_active(), "is_slowmo_active 已复位")

func _test_slowmo_no_stack() -> void:
	Engine.time_scale = 1.0
	GameManager.request_slowmo(0.4)
	var first_scale: float = Engine.time_scale
	# 叠加请求必须被忽略，不能把 0.25 再乘一次
	GameManager.request_slowmo(0.4)
	_check(is_equal_approx(Engine.time_scale, first_scale),
		"慢动作不叠加（两次请求后仍 %.2f）" % Engine.time_scale)
	await get_tree().create_timer(0.7, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "叠加请求后仍能正常恢复")

func _test_slowmo_clamp() -> void:
	Engine.time_scale = 1.0
	# 请求 5 秒，必须被钳制到 PDF 上限 0.6 秒
	var start: int = Time.get_ticks_msec()
	GameManager.request_slowmo(5.0)
	await get_tree().create_timer(0.9, true, false, true).timeout
	var elapsed: int = Time.get_ticks_msec() - start
	# 关键断言：0.9 秒墙钟后必须已恢复（若未钳制，5 秒请求此刻仍是 0.25 倍速）
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"5 秒请求在 0.9 秒墙钟内已恢复（实际耗时 %d ms，未钳制则仍为 0.25）" % elapsed)

func _test_state_machine() -> void:
	Engine.time_scale = 1.0
	var states: Array[int] = []
	var cb: Callable = func(s: int) -> void: states.append(s)
	EventBus.game_state_changed.connect(cb)
	GameManager.start_level(null, null, null)
	_check(GameManager.is_playing(), "start_level 后状态为 PLAYING")
	GameManager.pause_game()
	_check(GameManager.state() == GameManager.GameState.PAUSED, "pause_game 进入 PAUSED")
	GameManager.resume_game()
	_check(GameManager.is_playing(), "resume_game 回到 PLAYING")
	_check(states.size() >= 3, "game_state_changed 广播 %d 次" % states.size())
	# 存档往返
	var ok: bool = GameManager.save_game()
	_check(ok, "save_game 写入成功")
	var loaded: Dictionary = GameManager.load_game()
	_check(loaded.get("version", 0) == 1, "load_game 读回 version=1")
	EventBus.game_state_changed.disconnect(cb)
	get_tree().paused = false
	Engine.time_scale = 1.0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [PASS] ", label)
	else:
		print("  [FAIL] ", label)
		_errors.append(label)

func _report() -> void:
	print("=== SLOWMO TEST END ===")
	if _errors.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAILED" % _errors.size())
		for e: String in _errors:
			print("  - ", e)
	get_tree().quit(0 if _errors.is_empty() else 1)
