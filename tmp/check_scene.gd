# 场景脚本：挂在 tmp/check_scene.tscn 的根 Node2D 上
extends Node2D

func _ready() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.4, 0.3, 1.0))
	var tex := ImageTexture.create_from_image(img)

	var files := [
		"res://shaders/zombie_hit_flash.gdshader",
		"res://shaders/muzzle_flash.gdshader",
		"res://shaders/blood_hit_effect.gdshader",
	]
	for f in files:
		var sp := Sprite2D.new()
		sp.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = load(f)
		sp.material = mat
		add_child(sp)
		print("ATTACHED ", f)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("RENDER_DONE")
	get_tree().quit(0)
