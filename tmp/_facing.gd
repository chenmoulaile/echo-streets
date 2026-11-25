## 判定 panel 的可见面：把同一块招牌分别用 "x+" 与 "x-" 放到右墙 x=+12.92，
## 相机站在中庭 (6,1.6,0) 朝 +X 看。哪一块可见，就说明哪种 axis 朝向中庭。
## 跑法: Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/_facing_runner.tscn
extends Node

const K := preload("res://scripts/level/chapter_kit.gd")
const B := preload("res://scripts/level/chapter_builder.gd")

var _cam: Camera3D
var _root: Node3D

func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)
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

	var geo: Array = []
	# 右墙（x=+13，与 chapter_03_atrium.gd:84 完全一致：axis "x-"）
	geo.append(K.panel(Vector3(13.0, 2.6, 0.0), Vector2(36.0, 5.2), "x-", "WhiteWall",
		Color(0.96, 0.97, 0.99)))
	# 招牌 A：axis "x+"（章节 :158 对右墙用的就是这个）放在 z=-3
	geo.append(K.panel(Vector3(12.62, 2.05, -3.0), Vector2(3.2, 0.42), "x+", "WarningLine",
		Color(1.0, 1.0, 0.9), 1.0, false))
	# 招牌 B：axis "x-" 放在 z=+3
	geo.append(K.panel(Vector3(12.62, 2.05, 3.0), Vector2(3.2, 0.42), "x-", "WarningLine",
		Color(1.0, 1.0, 0.9), 1.0, false))

	var lamps: Array = [
		K.lamp(Vector3(6.0, 5.0, 0.0), Color(1.0, 0.98, 0.94), 3.4, 14.0),
	]
	var occluders: Dictionary = B.call("build_occluders", geo)
	for g: Dictionary in geo:
		var mesh: ArrayMesh = B.call("build_panel_public", g, lamps,
			Color(0.40, 0.41, 0.43), Color(0.20, 0.196, 0.192), occluders)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = load("res://assets/materials/%s.png" % g["mat"])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		mi.material_override = mat
		_root.add_child(mi)

	_cam.global_position = Vector3(6.0, 1.6, 0.0)
	_cam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tmp/_facing.png")
	print("[facing] saved")

	# 采样：招牌 A 应在屏幕左侧、招牌 B 在右侧
	var TH: float = tan(deg_to_rad(37.5))
	for label: String in ["A_xplus_z-3", "B_xminus_z+3"]:
		var wz: float = -3.0 if label.begins_with("A") else 3.0
		var depth: float = 12.62 - 6.0
		var sx: float = ((wz - 0.0) / depth) / TH
		var px: int = int(round(240.0 + sx * 240.0))
		var wy: float = 2.05 - 1.6
		var sy: float = (wy / depth) / (TH * 270.0 / 480.0)
		var py: int = int(round(135.0 - sy * 135.0))
		var c: Color = img.get_pixel(clampi(px, 0, 479), clampi(py, 0, 269))
		print("[facing] %s  screen=(%d,%d)  rgb=(%.3f,%.3f,%.3f)" % [
			label, px, py, c.r, c.g, c.b])
	get_tree().quit()
