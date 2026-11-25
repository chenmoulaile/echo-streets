## 一次性验证：确认 panel 的 "x+"/"x-" 法线朝向语义，以及招牌面是否被背面剔除。
## 相机在原点朝 +X 看，x=12.9 处放两块同材质 panel：
##   z=-2 用 "x+"，z=+2 用 "x-"。哪块可见就说明哪个字符串的法线朝 -X（面向中庭）。
extends Node3D

const K := preload("res://scripts/level/chapter_kit.gd")
const B := preload("res://scripts/level/chapter_builder.gd")
const LB := preload("res://scripts/level/light_baker.gd")
const ChapterDataScript := preload("res://scripts/level/chapter_data.gd")

func _ready() -> void:
	print("[normals] axes(x+) = ", LB.axes("x+"), "  normal=", LB.axes("x+")[2])
	print("[normals] axes(x-) = ", LB.axes("x-"), "  normal=", LB.axes("x-")[2])

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.environment = e
	add_child(env)

	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 300.0
	add_child(cam)
	cam.global_position = Vector3(0.0, 2.0, 0.0)
	cam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)

	var d = ChapterDataScript.make("probe", "PROBE", "PROBE")
	d.mesh_step = 1.0
	d.with_ambient(Color(0.46, 0.48, 0.52), Color(0.26, 0.25, 0.24))
	# 左（z=-2.5）用 "x+"，右（z=+2.5）用 "x-"；材质用不透明的高对比贴图
	d.add(K.panel(Vector3(12.9, 2.0, -2.5), Vector2(3.2, 2.0), "x+", "WarningLine",
		Color(1, 1, 1), 1.0, false, true))
	d.add(K.panel(Vector3(12.9, 2.0, 2.5), Vector2(3.2, 2.0), "x-", "WarningLine",
		Color(1, 1, 1), 1.0, false, true))
	B.build(d, self)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tmp/_normals.png")
	print("[normals] saved %dx%d (left=z-2.5 uses x+ , right=z+2.5 uses x-)" % [
		img.get_width(), img.get_height()])
	# 采样左右两块的中心像素亮度，判断哪块真的被渲染出来
	var cx: int = img.get_width() / 2
	var cy: int = img.get_height() / 2
	print("[normals] pixel(left)=", img.get_pixel(cx - 60, cy), "  pixel(right)=",
		img.get_pixel(cx + 60, cy))
	get_tree().quit()
