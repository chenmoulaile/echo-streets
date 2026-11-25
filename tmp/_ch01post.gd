## 取证：对比「探针 post 覆盖」与「真机 post 覆盖」两套参数下的 ch01 画面。
## 起因：tmp/ChapterProbe.gd:75-82 的 base 字典只有 7 个键，而
##   chapter_01_lobby.gd:43-48 的 with_post 传了 10 个键 ——
##   palette_levels / dither_strength / curvature / chromatic_aberration
##   在探针里从未被写入，截帧一直跑的是 shader 默认值。
## 本探针只建 chapter_01，两套参数各抓同一批机位。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/_ch01post_runner.tscn
extends Node

const OUT_A := "res://tmp/shots/ch01_probe_post/"   # 复刻现有探针（7 键）
const OUT_B := "res://tmp/shots/ch01_real_post/"    # 复刻 level.gd（全键覆盖）
const POST_SHADER := "res://shaders/pixelzombie_postprocess.gdshader"

var _cam: Camera3D
var _root: Node3D
var _env_node: WorldEnvironment
var _probe_env: Environment
var _postfx: CanvasLayer
var _post_rect: ColorRect

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_A))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_B))
	_root = Node3D.new()
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
	_build_postfx()

	var script: GDScript = load("res://scripts/level/chapter_01_lobby.gd")
	var data: RefCounted = script.call("build")
	var errs: PackedStringArray = data.call("validate")
	print("[ch01post] validate errs=%s" % str(errs))
	var stats: Dictionary = load("res://scripts/level/chapter_builder.gd").call("build", data, _root)
	print("[ch01post] build %s" % str(stats))

	var post: Dictionary = data.get("post")
	print("[ch01post] chapter post keys = %s" % str(post.keys()))

	# A) 复刻 tmp/ChapterProbe.gd 的 7 键基线
	_apply_probe_base(post)
	await _all_shots(OUT_A, data)

	# B) 复刻 scripts/level/level.gd:156-157 的逐键覆盖（真机路径）
	_apply_real(post)
	await _all_shots(OUT_B, data)

	print("[ch01post] done")
	get_tree().quit()

func _build_postfx() -> void:
	_postfx = CanvasLayer.new()
	_postfx.layer = 1
	add_child(_postfx)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(POST_SHADER)
	_post_rect.material = mat
	_postfx.add_child(_post_rect)

## 与 tmp/ChapterProbe.gd:70-82 逐字一致的基线（7 键）
func _apply_probe_base(post: Dictionary) -> void:
	var mat := _post_rect.material as ShaderMaterial
	var base := {
		"pixel_size": 1.0, "brightness": 1.16, "contrast": 1.02,
		"saturation": 1.0, "lift": 0.035, "vignette_strength": 0.20,
		"scanline_strength": 0.10,
	}
	for k: String in base.keys():
		mat.set_shader_parameter(StringName(k), float(post.get(k, base[k])))
	print("[ch01post] A probe-base applied")

## 与 scripts/level/level.gd:156-157 一致：先把 main.tscn 的基线全写一遍，再逐键覆盖 post
func _apply_real(post: Dictionary) -> void:
	var mat := _post_rect.material as ShaderMaterial
	var base := {
		"pixel_size": 1.0, "palette_levels": 8.0, "dither_strength": 1.0,
		"enable_crt": true, "curvature": 0.06, "chromatic_aberration": 1.0,
		"scanline_height": 1.0, "saturation": 1.0, "contrast": 1.02,
		"brightness": 1.16, "lift": 0.035, "vignette_strength": 0.20,
		"scanline_strength": 0.10,
	}
	for k: String in base.keys():
		mat.set_shader_parameter(StringName(k), base[k])
	for k: String in post.keys():
		mat.set_shader_parameter(StringName(k), post[k])
	print("[ch01post] B real-post applied: palette=%s dither=%s curv=%s ca=%s" % [
		mat.get_shader_parameter(&"palette_levels"), mat.get_shader_parameter(&"dither_strength"),
		mat.get_shader_parameter(&"curvature"), mat.get_shader_parameter(&"chromatic_aberration")])

func _all_shots(dir: String, data: RefCounted) -> void:
	var start: Vector3 = data.get("player_start")
	var yaw: float = float(data.get("player_yaw"))
	await _shot(dir, "00_player", start + Vector3(0.0, 1.6, 0.0), yaw, 0.0)
	await _shot(dir, "01_center", Vector3(0.0, 2.4, 0.0), 0.0, 0.0)
	await _shot(dir, "02_back", Vector3(0.0, 1.7, -14.0), 180.0, 0.0)
	await _shot(dir, "03_right", Vector3(7.0, 1.6, 2.0), -70.0, 0.0)
	await _shot(dir, "04_left", Vector3(-7.0, 1.6, 2.0), 70.0, 0.0)
	await _shot(dir, "05_top", Vector3(start.x, 2.85, start.z * 0.5), yaw, -52.0)

func _shot(dir: String, tag: String, pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	_cam.global_position = pos
	_cam.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("[ch01post] %s capture NULL" % tag)
		return
	var out: String = dir + tag + ".png"
	print("[ch01post] %s %dx%d save=%d" % [out, img.get_width(), img.get_height(), img.save_png(out)])
