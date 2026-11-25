# 调试：确认 .gdshader 载入后 code 是否可读
extends SceneTree

func _init() -> void:
	var sh := load("res://tmp/min_test.gdshader")
	print("type=", sh.get_class() if sh else "null")
	if sh is Shader:
		var code: String = sh.code
		print("code_len=", code.length())
		print("code_head=[", code.substr(0, 80), "]")
	quit(0)
