## 教程提示 + 丧尸 billboard 的实机截帧。
## headless 只能证明不报错，证明不了「提示真的出现在屏幕上」「纸片人真的转向镜头」。
## 运行：Godot --path D:\mygame res://tmp/tutorial_shot_runner.tscn
extends Node

const SHOT_DIR := "res://tmp/shots/tutorial/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	_shot("00_boot")

	# TutorialFlow 的 FIRST_DELAY 是 1.6 秒，等到 2.4 秒第一条提示（MOVE）应已亮起
	await get_tree().create_timer(1.8).timeout
	_shot("01_tutorial_move")

	# 走两步触发 MOVE 完成 → 推进到 FIRE
	var player: Node3D = main.get_node(^"Player")
	var start: Vector3 = player.global_position
	player.global_position = start + Vector3(1.2, 0.0, 0.0)
	await get_tree().create_timer(1.4).timeout
	_shot("02_tutorial_fire")
	player.global_position = start

	# billboard 验证：把镜头转 180 度，丧尸仍应正面朝我（而不是背面/侧面）
	var rig: Node3D = main.get_node(^"Player/CameraRig")
	player.rotation.y = PI
	await get_tree().create_timer(0.5).timeout
	_shot("03_billboard_turned")

	# 摆三只丧尸到正前方，看纸片人是否面向镜头
	var cam: Camera3D = main.get_node(^"Player/CameraRig/Camera3D")
	var placed: int = 0
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if not n.call(&"is_active_zombie"):
			continue
		var offs: Array[Vector3] = [
			Vector3(-1.8, -0.9, -4.0), Vector3(0.4, -0.9, -5.2), Vector3(2.2, -0.9, -6.4),
		]
		if placed >= offs.size():
			break
		n.set_physics_process(false)
		n.global_position = cam.global_position + offs[placed]
		placed += 1
	await get_tree().create_timer(0.5).timeout
	_shot("04_billboard_front")

	print("[tut_shot] done  zombies=%d" % placed)
	get_tree().quit()

func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = SHOT_DIR + tag + ".png"
	var err: int = img.save_png(path)
	if err == OK:
		print("[tut_shot] %s  %dx%d" % [path, img.get_width(), img.get_height()])
	else:
		push_error("保存 %s 失败 err=%d" % [path, err])
