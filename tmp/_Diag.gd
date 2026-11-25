## Minimal diagnostic: four panels facing the camera, sample the center pixel of each.
## A) WarningLine tiled=false  (copy of ch03:155-156 shopfront sign)
## B) WarningLine tiled=true
## C) RGB_Screen tiled=false emissive=true (copy of ch03:127-129 mezzanine lightbox)
## D) WhiteCeiling_MetalEdge tiled=true emissive=true (copy of ch03:173-174 light strip)
extends Node3D

const K := preload("res://scripts/level/chapter_kit.gd")
const B := preload("res://scripts/level/chapter_builder.gd")
const ChapterDataScript := preload("res://scripts/level/chapter_data.gd")

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.environment = e
	add_child(env)

	var d = ChapterDataScript.make("probe", "PROBE", "PROBE")
	d.mesh_step = 1.0
	d.with_ambient(Color(0.46, 0.48, 0.52), Color(0.26, 0.25, 0.24))

	d.add(K.panel(Vector3(0, 0, 0), Vector2(20, 6), "z+", "WhiteWall", Color(0.96, 0.97, 0.99)))
	d.add(K.panel(Vector3(-6.0, 2.0, 0.10), Vector2(3.2, 0.42), "z+", "WarningLine",
		Color(1, 1, 1), 1.0, false))
	d.add(K.panel(Vector3(-2.0, 2.0, 0.10), Vector2(3.2, 0.42), "z+", "WarningLine",
		Color(1, 1, 1), 1.0, true))
	d.add(K.panel(Vector3(2.0, 2.0, 0.10), Vector2(3.2, 0.42), "z+", "RGB_Screen",
		Color(0.72, 0.86, 1.0), 1.0, false, true))
	d.add(K.panel(Vector3(6.0, 2.0, 0.10), Vector2(3.2, 0.42), "z+", "WhiteCeiling_MetalEdge",
		Color(1.0, 0.99, 0.96), 0.5, true, true))
	print("[diag] geometry count = ", d.geometry.size())
	B.build(d, self)
	print("[diag] children after build = ", get_child_count())

	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 300.0
	add_child(cam)
	cam.global_position = Vector3(0, 2.0, 12.0)
	cam.rotation = Vector3(0, 0, 0)

	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tmp/_diag.png")
	var mpp: float = 2.0 * tan(deg_to_rad(37.5)) * 12.0 / 270.0
	print("[diag] meters per pixel = %.5f" % mpp)
	var wxs: Array = [-6.0, -2.0, 2.0, 6.0]
	var names: Array = ["WarningLine/tiled=false", "WarningLine/tiled=true",
		"RGB_Screen/emissive", "MetalEdge/emissive"]
	for i: int in range(4):
		var sx: int = int(round(240.0 + float(wxs[i]) / mpp))
		var c: Color = img.get_pixel(clampi(sx, 0, 479), 135)
		print("[diag] %-24s screenx=%3d rgb=(%.3f,%.3f,%.3f)" % [String(names[i]), sx, c.r, c.g, c.b])
	print("[diag] saved _diag.png")
	get_tree().quit()
