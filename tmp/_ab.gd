## 决定性 A/B：正常构建 chapter_03，再在"招牌应在的位置"补一块 axis 修正后的 WarningLine，
## 同一机位截图。若只有补的那块可见 → 章节 :151/:131 的 axis 是反的（背面剔除）。
## 跑法: Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/_ab_runner.tscn
extends Node3D

const K := preload("res://scripts/level/chapter_kit.gd")
const B := preload("res://scripts/level/chapter_builder.gd")
const CH := preload("res://scripts/level/chapter_03_atrium.gd")

var _cam: Camera3D

func _ready() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env_node.environment = env
	add_child(env_node)

	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.05
	_cam.far = 300.0
	add_child(_cam)

	var d = CH.build()
	var info: Dictionary = B.build(d, self)
	print("[ab] chapter build ", info)

	# 补两块 axis 修正后的招牌：右墙 sx=+1 → 应为 "x-"，左墙 sx=-1 → 应为 "x+"
	var holder := Node3D.new()
	holder.name = "FixProbe"
	add_child(holder)
	var fix = ChapterData.make("fixprobe", "FIX PROBE", "A/B")
	fix.mesh_step = 1.0
	fix.add(K.panel(Vector3(12.62, 2.05, -3.0), Vector2(3.2, 0.42), "x-", "WarningLine",
		Color(1.0, 1.0, 0.9), 1.0, false))
	fix.add(K.panel(Vector3(-12.62, 2.05, -3.0), Vector2(3.2, 0.42), "x+", "WarningLine",
		Color(1.0, 1.0, 0.9), 1.0, false))
	# 灯箱对照：同一位置，两种 axis 各一块，emissive=true + RGB_Screen
	fix.add(K.panel(Vector3(12.94, 4.20, -6.0), Vector2(2.6, 1.0), "x-", "RGB_Screen",
		Color(0.72, 0.86, 1.0), 1.0, false, true))
	fix.add(K.panel(Vector3(12.94, 4.20, -9.0), Vector2(2.6, 1.0), "x+", "RGB_Screen",
		Color(0.72, 0.86, 1.0), 1.0, false, true))
	var info2: Dictionary = B.build(fix, holder)
	print("[ab] fixprobe build ", info2)

	# 机位 1：站在 z=-3 店面前，正对右墙招牌（x=12.62, y=2.05, z=-3）
	await _shoot(Vector3(7.0, 1.6, -3.0), -90.0, 0.0, "ab_sign_right")
	# 机位 2：正对左墙招牌
	await _shoot(Vector3(-7.0, 1.6, -3.0), 90.0, 0.0, "ab_sign_left")
	# 机位 3：正对二层灯箱 —— z=-6 那块是 "x-"，z=-9 那块是 "x+"
	await _shoot(Vector3(8.0, 3.6, -6.0), -90.0, 12.0, "ab_box_xminus")
	await _shoot(Vector3(8.0, 3.6, -9.0), -90.0, 12.0, "ab_box_xplus")
	get_tree().quit()

func _shoot(pos: Vector3, yaw: float, pitch: float, tag: String) -> void:
	_cam.global_position = pos
	_cam.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tmp/_ab_%s.png" % tag)
	var yellow: int = 0
	var yx0: int = 9999
	var yx1: int = -1
	var yy0: int = 9999
	var yy1: int = -1
	for y: int in 270:
		for x: int in 480:
			var c: Color = img.get_pixel(x, y)
			var r: float = c.r * 255.0
			var g: float = c.g * 255.0
			var b: float = c.b * 255.0
			if r > 80.0 and g > 75.0 and b < g * 0.70 and absf(r - g) < 70.0:
				yellow += 1
				yx0 = mini(yx0, x)
				yx1 = maxi(yx1, x)
				yy0 = mini(yy0, y)
				yy1 = maxi(yy1, y)
	print("[ab] %-14s yellow=%d bbox x=%d..%d y=%d..%d" % [tag, yellow, yx0, yx1, yy0, yy1])
