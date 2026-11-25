extends SceneTree

# 逐一加载并实例化 ShaderMaterial，触发 Godot 4 着色器编译检查
func _init() -> void:
	var files := [
		"res://shaders/pixelzombie_postprocess.gdshader",
		"res://shaders/zombie_hit_flash.gdshader",
		"res://shaders/muzzle_flash.gdshader",
		"res://shaders/blood_hit_effect.gdshader",
		"res://shaders/retro_palette_filter.gdshader",
	]
	var ok := true
	for f in files:
		var s: Shader = load(f)
		if s == null:
			ok = false
			print("LOAD_FAIL ", f)
			continue
		var mat := ShaderMaterial.new()
		mat.shader = s
		var code := s.code
		print("SHADER_OK ", f, " type=", s.get_mode(), " len=", code.length())
	# 延迟一帧让渲染服务器报编译错误
	await process_frame
	await process_frame
	print("ALL_DONE ok=", ok)
	quit(0 if ok else 1)
