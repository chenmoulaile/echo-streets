## 判定 panel 的可见朝向：右墙 x=+13 用 "x-"（与 chapter_03_atrium.gd:84 一致），
## 墙上挂两块 WarningLine 招牌，z=-3 用 "x+"、z=+3 用 "x-"，相机在中庭 (7,1.6,0) 朝 +X。
## 哪块可见 = 哪种 axis 朝中庭。
## 跑法: Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/_facing2_runner.tscn
extends Node3D

const K := preload("res://scripts/level/chapter_kit.gd")
const B := preload("res://scripts/level/chapter_builder.gd")
const CD := preload("res://scripts/level/chapter_data.gd")

var _cam: Camera3D

func _ready() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env_node.environment = env
	add_child(env_node)

	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.05
	_cam.far = 300.0
	add_child(_cam)
	_cam.global_position = Vector3(7.0, 1.6, 0.0)
	_cam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)

	var d = CD.make("facing_test", "FACING", "TEST")
	d.mesh_step = 1.0
	d.with_ambient(Color(0.46, 0.48, 0.52), Color(0.26, 0.25, 0.24))
	# 右墙：与 chapter_03_atrium.gd:84 完全一致（x=+13 用 "x-"）
	d.add(K.panel(Vector3(13.0, 2.6, 0.0), Vector2(36.0, 5.2), "x-", "WhiteWall",
		Color(0.96, 0.97, 0.99)))
	# 招牌 A：axis "x+"（章节 :151 对右墙用的就是这个），放在 z=-3
	d.add(K.panel(Vector3(12.62, 2.05, -3.0), Vector2(3.2, 0.42), "x+", "WarningLine",
		Color(1.0, 1.0, 0.9), 1.0, false))
	# 招牌 B：axis "x-" 放在 z=+3
	d.add(K.panel(Vector3(12.62, 2.05, 3.0), Vector2(3.2, 0.42), "x-", "WarningLine",
		Color(1.0, 1.0, 0.9), 1.0, false))
	# 灯箱 C：RGB_Screen emissive，"x+"（章节 :131 对右墙用的），z=-6
	d.add(K.panel(Vector3(12.94, 4.2, -6.0), Vector2(2.6, 1.0), "x+", "RGB_Screen",
		Color(0.72, 0.86, 1.0), 1.0, false, true))
	# 灯箱 D：RGB_Screen emissive，"x-"，z=+6
	d.add(K.panel(Vector3(12.94, 4.2, 6.0), Vector2(2.6, 1.0), "x-", "RGB_Screen",
		Color(0.72, 0.86, 1.0), 1.0, false, true))
	d.lamps.append(K.lamp(Vector3(11.82, 1.9, 0.0), Color(0.94, 0.97, 1.0), 1.1, 4.5))
	d.lamps.append(K.lamp(Vector3(6.0, 4.95, 0.0), Color(1.0, 0.98, 0.94), 3.4, 12.0))

	var info: Dictionary = B.build(d, self)
	print("[facing2] build ", info)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tmp/_facing2.png")

	# 相机 (7,1.6,0) yaw-90 → 视线 +X。屏幕坐标按 fov75 / 480x270 反投影。
	var TH: float = tan(deg_to_rad(37.5))
	var TV: float = TH * 270.0 / 480.0
	var cam := Vector3(7.0, 1.6, 0.0)
	for spec: Array in [
		["sign_xplus_z-3", Vector3(12.62, 2.05, -3.0)],
		["sign_xminus_z+3", Vector3(12.62, 2.05, 3.0)],
		["box_xplus_z-6", Vector3(12.94, 4.2, -6.0)],
		["box_xminus_z+6", Vector3(12.94, 4.2, 6.0)],
	]:
		var w: Vector3 = spec[1]
		var depth: float = w.x - cam.x
		var sx: float = ((w.z - cam.z) / depth) / TH
		var sy: float = ((w.y - cam.y) / depth) / TV
		var px: int = clampi(int(round(240.0 + sx * 240.0)), 0, 479)
		var py: int = clampi(int(round(135.0 - sy * 135.0)), 0, 269)
		var c: Color = img.get_pixel(px, py)
		print("[facing2] %-18s screen=(%d,%d) rgb=(%.3f,%.3f,%.3f)" % [
			spec[0], px, py, c.r, c.g, c.b])
	get_tree().quit()
