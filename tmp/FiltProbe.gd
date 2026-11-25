extends Node

## 探针：确认 Godot 4.7 里可用的纹理过滤枚举名，避免写错常量名。
func _ready() -> void:
	var names: Array[String] = [
		"TEXTURE_FILTER_NEAREST",
		"TEXTURE_FILTER_LINEAR",
		"TEXTURE_FILTER_NEAREST_WITH_MIPMAPS",
		"TEXTURE_FILTER_LINEAR_WITH_MIPMAPS",
		"TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC",
	]
	for n: String in names:
		var ok: bool = false
		var v: int = -1
		match n:
			"TEXTURE_FILTER_NEAREST": ok = true; v = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			"TEXTURE_FILTER_LINEAR": ok = true; v = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			"TEXTURE_FILTER_NEAREST_WITH_MIPMAPS": ok = true; v = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			"TEXTURE_FILTER_LINEAR_WITH_MIPMAPS": ok = true; v = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			"TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC": ok = true; v = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		print("[filt] %s ok=%s value=%d" % [n, str(ok), v])
	# 同时确认 3D 默认 mipmap 生成开关的键名
	print("[filt] default_texture_filter=", ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", "MISSING"))
	print("[filt] anisotropic=", ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", "MISSING"))
	get_tree().quit()
