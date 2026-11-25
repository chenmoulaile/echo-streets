## 审核专用：只建第 2 章（office），用与 ChapterProbe 完全相同的六个机位重抓。
## 必须带窗口跑（--headless 读不到 viewport 纹理）:
##   Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/audit_ch02_runner.tscn
extends Node

const OUT_DIR := "res://tmp/shots/chapter_audit/"

var _cam: Camera3D
var _root: Node3D
var _env_node: WorldEnvironment
var _probe_env: Environment

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_root = Node3D.new()
	_root.name = "ProbeRoot"
	add_child(_root)

	_env_node = WorldEnvironment.new()
	_probe_env = Environment.new()
	_probe_env.background_mode = Environment.BG_COLOR
	_probe_env.background_color = Color(0.05, 0.06, 0.08)
	_probe_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_env_node.environment = _probe_env
	add_child(_env_node)

	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.05
	_cam.far = 300.0
	add_child(_cam)

	await _probe(1, "res://scripts/level/chapter_02_office.gd")
	print("[audit_ch02] done")
	get_tree().quit()

func _probe(index: int, path: String) -> void:
	var key: String = "ch%02d" % (index + 1)
	var script: GDScript = load(path)
	var data: RefCounted = script.call("build")
	var errs: PackedStringArray = data.call("validate")
	if errs.is_empty():
		print("[%s] validate OK  kills=%d  geo=%d  lamps=%d  spawns=%d" % [
			key, data.call("total_kills"), data.get("geometry").size(),
			data.get("lamps").size(), data.get("spawn_points").size()])
	else:
		for m: String in errs:
			print("[%s] VALIDATE FAIL: %s" % [key, m])

	var chapter_has_sky: bool = not String(data.get("sky_texture")).is_empty()
	_env_node.environment = null if chapter_has_sky else _probe_env

	var t0: int = Time.get_ticks_msec()
	var stats: Dictionary = load("res://scripts/level/chapter_builder.gd").call(
		"build", data, _root)
	var has_sky: bool = load("res://scripts/level/chapter_builder.gd").call(
		"build_sky", data, _root)
	var ms: int = Time.get_ticks_msec() - t0
	print("[%s] build %s sky=%s  (%d ms)" % [key, str(stats), str(has_sky), ms])

	var start: Vector3 = data.get("player_start")
	var yaw: float = float(data.get("player_yaw"))
	await _shot("%s_00_player" % key, start + Vector3(0.0, 1.6, 0.0), yaw)
	await _shot("%s_01_center" % key, Vector3(0.0, 2.4, 0.0), 0.0)
	await _shot("%s_02_back" % key, Vector3(0.0, 1.7, -14.0), 180.0)
	await _shot("%s_03_right" % key, Vector3(7.0, 1.6, 2.0), -70.0)
	await _shot("%s_04_left" % key, Vector3(-7.0, 1.6, 2.0), 70.0)
	await _shot("%s_05_top" % key, start + Vector3(0.0, 6.5, 6.0), yaw, -38.0)

func _shot(tag: String, pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0) -> void:
	_cam.global_position = pos
	_cam.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("[%s] capture NULL" % tag)
		return
	var out: String = OUT_DIR + tag + ".png"
	var err: int = img.save_png(out)
	print("[%s] %dx%d save=%d" % [tag, img.get_width(), img.get_height(), err])
