## 颜色偏差 A/B 取证：同一只丧尸，分别用
##   a) 后期开 + 命中闪白着色器（当前线上配置）
##   b) 后期关 + 命中闪白着色器
##   c) 后期关 + 去掉 material_override（纯 Sprite3D 采样）
## 三种配置各抓一张，用来判断偏亮偏绿是后期、还是着色器、还是导入压缩导致。
## 运行（必须带窗口，headless 抓不到画面）：
##   Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/shot_raw_runner.tscn
extends Node

const SHOT_DIR := "res://tmp/shots/"

var _target: Sprite3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(1.2).timeout

	# 把一只丧尸摆到镜头正前方并冻结，避免它移动/转向影响取样
	var cam: Camera3D = main.get_node("Player/CameraRig/Camera3D")
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if not n.is_active_zombie():
			continue
		n.set_physics_process(false)
		n.set_process(false)
		n.global_position = cam.global_position + Vector3(0.0, -0.9, -4.0)
		n.rotation = Vector3.ZERO
		_target = n.get_node_or_null(^"Sprite3D") as Sprite3D
		break
	if _target == null:
		print("[raw] no active zombie found")
		get_tree().quit()
		return
	await get_tree().create_timer(0.5).timeout

	# a) 线上配置
	_shot("a_post_on")
	print("[raw] tex=%s size=%s" % [_target.texture, _target.texture.get_size() if _target.texture else "null"])

	# b) 关后期
	var fx: Node = main.get_node_or_null(^"PostFX")
	if fx != null:
		fx.visible = false
		await get_tree().create_timer(0.3).timeout
		_shot("b_post_off")

	# c) 再去掉材质覆盖
	var saved: Material = _target.material_override
	_target.material_override = null
	await get_tree().create_timer(0.3).timeout
	_shot("c_plain")

	# d) 恢复材质，但把 flash 相关 uniform 归零（排除闪白残留）
	_target.material_override = saved
	var mat: ShaderMaterial = saved as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"flash_amount", 0.0)
		mat.set_shader_parameter(&"rim_boost", 0.0)
		mat.set_shader_parameter(&"overexposure", 0.0)
		mat.set_shader_parameter(&"tint_amount", 0.0)
		await get_tree().create_timer(0.3).timeout
		_shot("d_no_fx_uniforms")
		print("[raw] flash=%s rim=%s over=%s" % [
			mat.get_shader_parameter(&"flash_amount"),
			mat.get_shader_parameter(&"rim_boost"),
			mat.get_shader_parameter(&"overexposure")])

	print("[raw] done")
	get_tree().quit()

func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = SHOT_DIR + tag + ".png"
	if img.save_png(path) == OK:
		print("[raw] %s  %dx%d" % [path, img.get_width(), img.get_height()])
