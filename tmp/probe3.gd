# 根因确认：Godot 4 shader 的注释符是 // 还是 #（# 是预处理指令）
extends SceneTree

func _test(label: String, code: String) -> void:
	var s := Shader.new()
	s.code = code
	print(label, " | mode=", s.get_mode(), " uniforms=", s.get_shader_uniform_list().size())


func _initialize() -> void:
	var body := "\nuniform float k : hint_range(0.0, 1.0) = 0.5;\nvoid fragment(){COLOR=vec4(k);}\n"

	_test("S1 slash-comment-first ", "// ascii comment\nshader_type canvas_item;" + body)
	_test("S2 slash-cn-first      ", "// 中文注释第一行\nshader_type canvas_item;" + body)
	_test("S3 slash-block-first   ", "// ======\n// 中文说明\n// ======\nshader_type canvas_item;" + body)
	_test("S4 hash-comment-first  ", "# ascii comment\nshader_type canvas_item;" + body)
	_test("S5 slash-inline        ", "shader_type canvas_item; // 尾随中文" + body)
	_test("S6 slash-cn-later      ", "shader_type canvas_item;\n// 中文注释" + body)
	quit(0)
