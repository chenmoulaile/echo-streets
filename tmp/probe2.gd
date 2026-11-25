# 变量隔离：确认「中文注释」是否是 shader 解析失败的唯一原因
extends SceneTree

func _test(label: String, code: String) -> void:
	var s := Shader.new()
	s.code = code
	var n := s.get_shader_uniform_list().size()
	print(label, " | mode=", s.get_mode(), " uniforms=", n)


func _initialize() -> void:
	var body := "\nuniform float k : hint_range(0.0, 1.0) = 0.5;\nvoid fragment(){COLOR=vec4(k);}\n"

	_test("V1 ascii-no-comment   ", "shader_type canvas_item;" + body)
	_test("V2 ascii-comment-first", "# ascii comment line\nshader_type canvas_item;" + body)
	_test("V3 cn-comment-first   ", "# 中文注释第一行\nshader_type canvas_item;" + body)
	_test("V4 cn-comment-later   ", "shader_type canvas_item;\n# 中文注释在第二行" + body)
	_test("V5 cn-inline-trailing ", "shader_type canvas_item; # 尾随中文" + body)
	_test("V6 cn-block-first     ", "# ==========\n# 中文说明\n# ==========\nshader_type canvas_item;" + body)
	_test("V7 ascii-block-first  ", "# ==========\n# ascii note\n# ==========\nshader_type canvas_item;" + body)
	quit(0)
