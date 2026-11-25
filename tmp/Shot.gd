## 真实渲染截帧：headless 无法验证画面，必须在带窗口的进程里抓 viewport。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/shot_runner.tscn
extends Node

const SHOT_DIR := "res://tmp/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(1.2).timeout

	# 把几只丧尸拉到镜头前，保证画面里有人
	var cam: Camera3D = main.get_node("Player/CameraRig/Camera3D")
	var placed: int = 0
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if not n.is_active_zombie():
			continue
		var offs: Array[Vector3] = [
			Vector3(-1.6, -0.9, -4.5), Vector3(1.8, -0.9, -5.5), Vector3(0.2, -0.9, -7.0),
		]
		if placed >= offs.size():
			break
		n.set_physics_process(false)
		n.global_position = cam.global_position + offs[placed]
		placed += 1
	await get_tree().create_timer(0.6).timeout

	_shot("01_idle")
	# 开火：验证枪口火光 + 后坐 + 命中标记
	var pistol: Node = main.get_node("Player/CameraRig/Camera3D/WeaponMount/Pistol")
	pistol.pull_trigger()
	await get_tree().create_timer(0.06).timeout
	_shot("02_fire")
	pistol.release_trigger()

	# 换弹进度条
	pistol.start_reload()
	await get_tree().create_timer(0.5).timeout
	_shot("03_reload")

	# 死亡界面
	await get_tree().create_timer(1.0).timeout
	main.get_node("Player").take_damage(999.0, false, null)
	await get_tree().create_timer(0.5).timeout
	_shot("04_dead")

	print("[shot] done")
	get_tree().quit()

func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = SHOT_DIR + tag + ".png"
	var err: int = img.save_png(path)
	if err == OK:
		print("[shot] %s  %dx%d" % [path, img.get_width(), img.get_height()])
	else:
		push_error("保存 %s 失败 err=%d" % [path, err])
