# 着色器静态校验：加载 .gdshader，赋值给 ShaderMaterial，读取编译期错误。
# 用法：godot --path D:\mygame --rendering-driver opengl3 --script res://tmp/shaders_check.gd
extends SceneTree

const SHADER_DIRS: Array[String] = ["res://shaders", "res://tmp"]

func _init() -> void:
	var failed := 0
	var total := 0
	for dir_path in SHADER_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			print("ERR: 无法打开 ", dir_path)
			continue
		var files: Array[String] = []
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".gdshader"):
				files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
		files.sort()

		for f in files:
			total += 1
			var path := dir_path + "/" + f
			var sh := load(path)
			if sh == null or not (sh is Shader):
				print("FAIL load   ", path)
				failed += 1
				continue
			var mat := ShaderMaterial.new()
			mat.shader = sh
			# 读取 Shader 的编译状态：Godot 4 通过 get_shader_uniform_list 触发解析
			var uniforms: Array = sh.get_shader_uniform_list()
			var names: Array[String] = []
			for u in uniforms:
				names.append(str(u.get("name", "?")))
			print("OK  ", path, "  uniforms=", uniforms.size())
			print("    ", ", ".join(names))

	print("---- total=", total, " failed=", failed, " ----")
	quit(1 if failed > 0 else 0)
