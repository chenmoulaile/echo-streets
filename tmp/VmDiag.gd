## 最小诊断：SubViewport 里为什么渲染不出东西。
## 运行：Godot --path . res://tmp/vm_diag.tscn（不能带 --headless）
extends Node

const RW := 512
const RH := 384


func _ready() -> void:
	await _diag()
	get_tree().quit(0)


func _diag() -> void:
	print("=== VM DIAG ===")
	var vp := SubViewport.new()
	vp.size = Vector2i(RW, RH)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.4, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 58.0
	cam.near = 0.02
	cam.far = 8.0
	cam.current = true
	vp.add_child(cam)
	print("  cam current=%s pos=%s" % [cam.current, cam.global_position])

	var l := DirectionalLight3D.new()
	l.light_energy = 1.5
	vp.add_child(l)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.20)
	mi.mesh = bm
	mi.position = Vector3(0.0, 0.0, -0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.3, 0.2)
	mi.material_override = m
	vp.add_child(mi)
	print("  mesh added pos=%s visible=%s" % [mi.position, mi.visible])

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	if img == null:
		print("  IMAGE NULL")
		return
	print("  img %dx%d fmt=%d" % [img.get_width(), img.get_height(), img.get_format()])
	print("  center=%s  corner=%s" % [img.get_pixel(RW / 2, RH / 2), img.get_pixel(4, 4)])
	var p := ProjectSettings.globalize_path("res://tmp/vmraw/_diag.png")
	print("  save err=%d" % img.save_png(p))

	# 再试一次：SubViewport 挂到 root 下、并强制 camera 重新 current
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	var img2 := vp.get_texture().get_image()
	print("  retry center=%s" % [img2.get_pixel(RW / 2, RH / 2)])
	print("=== VM DIAG DONE ===")
