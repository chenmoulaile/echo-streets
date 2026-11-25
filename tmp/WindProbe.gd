## 绕序取证：判定 Godot 4 Compatibility 下哪种三角形绕序是正面。
## 背景：LightBaker 的 build_panel 用 u.cross(v).dot(n) 自动翻转绕序，
##   但实测地板/天花板/部分墙整片消失（tmp/shots/chapter/ch01_00_player.png），
##   说明翻转条件判反了。这里用两个已知绕序的四边形做对照，直接读像素亮度定性。
## 必须带窗口跑：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/wind_runner.tscn
extends Node

const OUT := "res://tmp/shots/wind/"

var _cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.environment = e
	add_child(env)

	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.near = 0.05
	_cam.position = Vector3(0.0, 0.0, 0.0)
	add_child(_cam)

	# 左侧：A 绕序 (v00, v10, v01)；右侧：B 绕序 (v00, v01, v10)
	# 两块都放在 z=-4，法线都朝 +Z（面向相机）。
	add_child(_quad("A", Vector3(-1.2, 0.0, -4.0), [0, 1, 2, 1, 3, 2]))
	add_child(_quad("B", Vector3(1.2, 0.0, -4.0), [0, 2, 1, 1, 2, 3]))

	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT + "wind.png")
	# 采样：A 中心 ≈ (120,135)，B 中心 ≈ (360,135)
	print("[wind] A_left_brightness=%.3f" % _lum(img, 120, 135))
	print("[wind] B_right_brightness=%.3f" % _lum(img, 360, 135))
	print("[wind] 结论：亮度高的一侧是正面可见的绕序")
	get_tree().quit()

func _quad(tag: String, center: Vector3, idx: Array) -> MeshInstance3D:
	var h: float = 0.9
	var verts: PackedVector3Array = PackedVector3Array([
		center + Vector3(-h, -h, 0.0), center + Vector3(h, -h, 0.0),
		center + Vector3(-h, h, 0.0), center + Vector3(h, h, 0.0)])
	var normals: PackedVector3Array = PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in idx:
		indices.append(i)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Quad_" + tag
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.2, 0.2) if tag == "A" else Color(0.2, 1.0, 0.3)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = m
	return mi

func _lum(img: Image, x: int, y: int) -> float:
	var c: Color = img.get_pixel(x, y)
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
