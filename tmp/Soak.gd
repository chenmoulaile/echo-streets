## 30 秒实战 soak：真实推进 main.tscn，模拟玩家持续射击，统计帧率/击杀/波次。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/soak_runner.tscn
## 存在理由：探针只做逐项断言，不证明"连续 30 秒循环不崩、帧率不塌、波次能推进"。
extends Node

const DURATION := 30.0

var _main: Node
var _player: Node
var _spawner: Node
var _weapon: Node
var _frames := 0
var _dt_sum := 0.0
var _worst := 0.0
var _shots := 0

func _ready() -> void:
	print("=== SOAK ", DURATION, "s ===")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().create_timer(0.5).timeout
	_player = _main.get_node_or_null("Player")
	_spawner = _main.get_node_or_null("WaveSpawner")
	if _player == null or _spawner == null:
		print("SOAK ABORT: 缺少 Player/WaveSpawner")
		get_tree().quit(1)
		return
	_weapon = _player.call(&"active_weapon")
	await _loop()
	_report()
	get_tree().quit(0)

func _process(delta: float) -> void:
	if _main == null:
		return
	_frames += 1
	_dt_sum += delta
	_worst = maxf(_worst, delta)
	# 每帧把枪口朝向最近的活跃丧尸并开火，模拟真实战斗压力
	if _weapon == null:
		return
	var z := _nearest_zombie()
	if z != null:
		_aim_at(z)
		_shots += 1
		_weapon.call(&"try_fire")
	# 空仓就换弹
	if _weapon.call(&"mag_ammo") <= 0 and not _weapon.call(&"is_reloading"):
		_weapon.call(&"start_reload")

func _nearest_zombie() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		var z := n as Node3D
		if z == null or not n.call(&"is_active_zombie"):
			continue
		var d: float = z.global_position.distance_squared_to(_player.global_position)
		if d < bd:
			bd = d
			best = z
	return best

func _aim_at(target: Node3D) -> void:
	var cam := _player.get_node_or_null(^"CameraRig/Camera3D") as Camera3D
	if cam == null:
		return
	var from: Vector3 = cam.global_position
	var to: Vector3 = target.global_position + Vector3.UP * 1.1
	var flat := to - from
	if flat.length() < 0.05:
		return
	# 只调 yaw/pitch，不碰位置，避免把角色推进墙里
	var yaw := atan2(-flat.x, -flat.z)
	var pitch := atan2(flat.y, Vector2(flat.x, flat.z).length())
	_player.rotation.y = yaw
	(_player.get_node(^"CameraRig") as Node3D).rotation.x = pitch

func _loop() -> void:
	var t := 0.0
	while t < DURATION:
		await get_tree().process_frame
		t += get_process_delta_time()

func _hp() -> float:
	var hc := _player.get_node_or_null(^"HealthComponent")
	if hc == null:
		return -1.0
	return float(hc.call(&"current_health"))

func _report() -> void:
	var avg := _dt_sum / maxf(float(_frames), 1.0)
	var fps := 1.0 / maxf(avg, 0.0001)
	var active := 0
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if n.call(&"is_active_zombie"):
			active += 1
	print("SOAK frames=%d avg_dt=%.3fms fps=%.1f worst=%.1fms" % [
		_frames, avg * 1000.0, fps, _worst * 1000.0])
	print("SOAK wave=%d phase=%d kills=%d alive=%d shots=%d hp=%.0f state=%d" % [
		_spawner.call(&"current_wave"),
		_spawner.call(&"current_phase"),
		GameManager.kill_count(),
		active,
		_shots,
		_hp(),
		GameManager.state()])
	var verdict := "PASS"
	if fps < 55.0:
		verdict = "FAIL(fps)"
	if _frames < 300:
		verdict = "FAIL(frames)"
	print("SOAK RESULT: ", verdict)
