## 一次性诊断：只建 ch03，用若干「合法机位」抓图，回答两个问题
##   1) 玩家抬头（pitch>0）时二层环廊到底能不能读出来
##   2) 俯视机位放回房间内部后，10x20 挑空是否可见（排除 ChapterProbe 机位穿墙的干扰）
## 跑法: Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/_ch03look_runner.tscn
extends Node

const OUT_DIR := "res://tmp/shots/_ch03look/"
const POST_SHADER := "res://shaders/pixelzombie_postprocess.gdshader"

var _cam: Camera3D
var _root: Node3D
var _post_rect: ColorRect

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_root = Node3D.new()
	add_child(_root)

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

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(POST_SHADER)
	_post_rect.material = mat
	layer.add_child(_post_rect)

	var data: RefCounted = load("res://scripts/level/chapter_03_atrium.gd").call("build")
	var stats: Dictionary = load("res://scripts/level/chapter_builder.gd").call(
		"build", data, _root)
	print("[look] build %s" % str(stats))

	_apply_post(data.get("post"))

	# 玩家抬头看二层环廊
	await _shot("a_eye_yaw0_pitch18", Vector3(0.0, 1.6, 15.0), 0.0, 18.0)
	await _shot("b_eye_z10_pitch25", Vector3(0.0, 1.6, 10.0), 0.0, 25.0)
	await _shot("c_eye_z0_pitch30", Vector3(0.0, 1.6, 0.0), 0.0, 30.0)
	# 合法俯视：机位在房间内部、天花下方
	await _shot("d_top_inside", Vector3(0.0, 4.9, 12.0), 0.0, -50.0)
	await _shot("e_top_inside2", Vector3(0.0, 4.9, 16.0), 0.0, -62.0)
	# 与官方 05 完全同参数，用来复现黑带
	await _shot("f_top_official", Vector3(0.0, 6.5, 21.0), 0.0, -38.0)
	# 只抬到天花板下方、仍在房间外 z=21 → 分离「高度」与「出墙」两个变量
	await _shot("g_z21_y48", Vector3(0.0, 4.8, 21.0), 0.0, -38.0)

	print("[look] done")
	get_tree().quit()

func _apply_post(post: Dictionary) -> void:
	var mat := _post_rect.material as ShaderMaterial
	if mat == null:
		return
	var base := {
		"pixel_size": 1.0, "brightness": 1.16, "contrast": 1.02,
		"saturation": 1.0, "lift": 0.035, "vignette_strength": 0.20,
		"scanline_strength": 0.10,
	}
	for k: String in base.keys():
		mat.set_shader_parameter(StringName(k), float(post.get(k, base[k])))

func _shot(tag: String, pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	_cam.global_position = pos
	_cam.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("[%s] capture NULL" % tag)
		return
	var err: int = img.save_png(OUT_DIR + tag + ".png")
	print("[%s] %dx%d save=%d" % [tag, img.get_width(), img.get_height(), err])
