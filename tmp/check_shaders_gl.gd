extends Node2D

# 用真 GL 上下文做语法级编译验证：把每个 canvas_item 着色器材质
# 挂到一个离屏 Sprite2D 上，强制渲染服务器实际编译。
# 着色器源码若含语法错误，Godot 会报 "Failed to compile shader" 并使材质变洋红。

var _sprites: Array[Sprite2D] = []
var _tex: ImageTexture

func _ready() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.4, 0.3, 1.0))
	_tex = ImageTexture.create_from_image(img)

	var files := [
		"res://shaders/zombie_hit_flash.gdshader",
		"res://shaders/muzzle_flash.gdshader",
		"res://shaders/blood_hit_effect.gdshader",
	]
	for f in files:
		var sp := Sprite2D.new()
		sp.texture = _tex
		var mat := ShaderMaterial.new()
		mat.shader = load(f)
		sp.material = mat
		add_child(sp)
		_sprites.append(sp)
		print("ATTACHED ", f)

	# 渲染几帧触发编译
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("RENDER_DONE")
	get_tree().quit(0)
