## billboard 近距决定性验证：相机贴到 3 米，绕丧尸转 4 个 90° 机位。
## 判据：若 billboard 生效，4 张里丧尸的轮廓完全一致（都是正面），只有 flip_h 可能镜像；
## 若未生效，纸片朝向固定，转到侧面时会塌成一条 1px 竖线、转到背面时看到后脑。
##
## 上一版的两个 bug（记下来别再犯）：
##   1. 偏移用世界坐标 `cam.global_position + Vector3(...)`，玩家转向后"前方"变到背后。
##      必须用相机基变换：`cam.global_transform * local_offset`。
##   2. 距离 6 米 + 480x270 逻辑屏，丧尸只有 ~40px 高，肉眼判不出朝向。近到 3 米。
##
## 运行：Godot --path D:\mygame res://tmp/billboard_shot_runner.tscn
extends Node

const SHOT_DIR := "res://tmp/shots/billboard/"
const RADIUS := 3.2

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout

	var player: Node3D = main.get_node(^"Player")
	var rig: Node3D = main.get_node(^"Player/CameraRig")

	var zombies: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if n is Node3D and n.call(&"is_active_zombie"):
			zombies.append(n as Node3D)
	if zombies.is_empty():
		push_error("没有活跃丧尸")
		get_tree().quit(1)
		return

	# 先把 billboard 属性读出来，这是引擎层面的直接证据
	var target: Node3D = zombies[0]
	var sprite: Sprite3D = target.get_node_or_null(^"Sprite3D") as Sprite3D
	if sprite != null:
		print("[bb] Sprite3D.billboard = %d  (1 = BILLBOARD_ENABLED)" % sprite.billboard)
		print("[bb] Sprite3D.texture_filter = %d" % sprite.texture_filter)
	else:
		print("[bb] 警告：没找到 Sprite3D")

	# 只留这一只，其余挪走
	for i in range(1, zombies.size()):
		zombies[i].global_position = Vector3(0.0, -50.0, 0.0)

	var center: Vector3 = target.global_position
	target.set_physics_process(false)
	target.global_position = center
	print("[bb] 靶心 %s" % center)

	for step_i in range(4):
		var ang: float = deg_to_rad(90.0 * float(step_i))
		var pos: Vector3 = center + Vector3(sin(ang), 0.0, cos(ang)) * RADIUS
		pos.y = center.y + 0.55
		player.global_position = pos
		var dir: Vector3 = (center - pos).normalized()
		player.rotation.y = atan2(-dir.x, -dir.z)
		# 平视，正对丧尸胸口
		rig.rotation.x = deg_to_rad(-4.0)
		await get_tree().create_timer(0.5).timeout
		_shot("close_%03d" % int(90.0 * float(step_i)))

	print("[bb] done")
	get_tree().quit()

func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = SHOT_DIR + tag + ".png"
	if img.save_png(path) == OK:
		print("[bb] %s" % path)
	else:
		push_error("保存 %s 失败" % path)
