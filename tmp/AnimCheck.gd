## 动画取证：把一只丧尸贴到镜头正前方，按固定间隔连拍，验证帧确实在切换。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/anim_runner.tscn
## headless 拿不到 viewport 内容，必须带窗口。
extends Node

const OUT := "res://tmp/shots/anim/"
const DIST := 2.6

var _zombie: Node3D
var _cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout

	_cam = main.get_node("Player/CameraRig/Camera3D")
	_zombie = _pick_zombie()
	if _zombie == null:
		push_error("anim: 场景里没有活跃丧尸")
		get_tree().quit()
		return
	# 冻结 AI 位置与物理，只让精灵动画继续跑
	_zombie.set_physics_process(false)
	_stick()
	await get_tree().create_timer(0.3).timeout

	await _capture_state(&"idle", 4, 0.26)
	await _capture_state(&"walk", 6, 0.12)
	await _capture_state(&"attack", 3, 0.12)
	await _capture_state(&"hurt", 2, 0.12)
	await _capture_state(&"death", 5, 0.18)

	print("[anim] done")
	get_tree().quit()

func _pick_zombie() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if n.call(&"is_active_zombie"):
			return n as Node3D
	return null

## 把丧尸摆到镜头正前、脚底贴地。每帧重摆一次，防止 AI 或物理把它挤走。
func _stick() -> void:
	var fwd: Vector3 = -_cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var feet: Vector3 = _cam.global_position + fwd * DIST
	feet.y = 0.0
	_zombie.global_position = feet
	_zombie.velocity = Vector3.ZERO

func _capture_state(state: StringName, frames: int, gap: float) -> void:
	var spr: Node = _zombie.get_node_or_null(^"Sprite3D")
	if spr == null:
		return
	spr.call(&"play", state, true)
	for i: int in frames:
		_stick()
		await get_tree().create_timer(gap).timeout
		var path: String = OUT + String(state) + "_" + str(i) + ".png"
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(path)
		print("[anim] %s anim=%s frame=%d" % [path, String(spr.call(&"current_anim")), i])
