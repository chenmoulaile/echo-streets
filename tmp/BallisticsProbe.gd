## 弹道专项探针：验证 muzzle_velocity 的两条命中路径都成立。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/ballistics_runner.tscn
## 为什么单独一个探针而不是塞进 Probe.gd：
##   Probe.gd 的射击断言只看"最终有没有掉血"，无法区分"同一帧掉血"（hitscan）
##   和"隔几帧掉血"（弹道）。初速改动的核心契约恰恰就是延迟，必须逐帧采样。
## 为什么用 EventBus.zombie_hit 计数而不是读丧尸血量：
##   血量会被多次测试累积扣光，一旦死亡就被对象池回收，后续断言全部失真。
##   信号里直接带 damage 与帧号，一次开火命中几颗、隔了几帧都能精确读出。
extends Node

var _pass := 0
var _fail := 0
var _main: Node
var _player: Node
var _frame: int = 0
## 每次开火前清空。元素 = [命中帧号, 伤害, 是否弱点]
var _hits: Array = []
var _record: bool = false

func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label, ("  [" + detail + "]") if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, ("  [" + detail + "]") if detail != "" else "")

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _process(_delta: float) -> void:
	_frame += 1

func _on_zombie_hit(_zombie: Node, damage: float, is_weakspot: bool) -> void:
	if _record:
		_hits.append([_frame, damage, is_weakspot])

func _ready() -> void:
	print("=== BALLISTICS PROBE ===")
	EventBus.zombie_hit.connect(_on_zombie_hit)
	await _run()
	print("=== RESULT pass=%d fail=%d ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

## 把一只活丧尸摆到玩家正前方 dist 米处并冻结物理，回满血，返回该丧尸。
func _place_target(dist: float) -> Node:
	var cam: Camera3D = _player.get_node("CameraRig/Camera3D")
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if not n.is_active_zombie():
			continue
		n.set_physics_process(false)
		var fwd: Vector3 = -cam.global_transform.basis.z
		n.global_position = cam.global_position + fwd * dist - Vector3(0.0, 0.9, 0.0)
		var hc: Node = n.get_node_or_null("HealthComponent")
		if hc != null:
			hc.call(&"reset_health")
		return n
	return null

## 开一枪，记录命中信号，返回 [命中数, 首帧延迟, 总伤害]
func _fire_and_measure(weapon: Node, max_frames: int = 40) -> Array:
	_hits.clear()
	_record = true
	var f0: int = _frame
	weapon.pull_trigger()
	weapon.release_trigger()
	for _i: int in max_frames:
		if not _hits.is_empty():
			break
		await get_tree().process_frame
	# 霰弹枪多弹丸可能不在同一帧全部结算，再等几帧收齐
	for _j: int in 6:
		await get_tree().process_frame
	_record = false
	var total: float = 0.0
	for h: Array in _hits:
		total += float(h[1])
	var delay: int = (int(_hits[0][0]) - f0) if not _hits.is_empty() else -1
	return [_hits.size(), delay, total]

func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await _wait(0.4)
	_player = _main.get_node_or_null("Player")
	if _player == null:
		_ok("Player 存在", false)
		return

	var mount: Node = _player.get_node("CameraRig/Camera3D/WeaponMount")
	var pistol: Node = mount.get_child(0)
	var shotgun: Node = mount.get_child(1)

	# —— 数据层 ——
	_ok("手枪 muzzle_velocity = 380", is_equal_approx(float(pistol.data.muzzle_velocity), 380.0),
		"%.0f" % float(pistol.data.muzzle_velocity))
	_ok("霰弹枪 muzzle_velocity = 410", is_equal_approx(float(shotgun.data.muzzle_velocity), 410.0),
		"%.0f" % float(shotgun.data.muzzle_velocity))
	_ok("validate() 无配置问题", pistol.data.validate().is_empty(),
		str(pistol.data.validate()))
	_ok("初速过低会被 validate 拦下", _low_velocity_flagged(pistol.data))

	# —— 弹道路径：近距离必须"隔帧"才命中 ——
	await _wait(1.4)
	_player.call(&"_equip", 0)
	await _wait(0.2)
	var z: Node = _place_target(4.0)
	if z == null:
		_ok("找到可用丧尸", false)
		return
	await _wait(0.15)
	var near: Array = await _fire_and_measure(pistol)
	_ok("4m 走弹道能命中", int(near[0]) == 1, "命中 %d 次" % int(near[0]))
	_ok("4m 命中延迟 > 0 帧（不是当帧 hitscan）", int(near[1]) > 0, "%d 帧" % int(near[1]))
	_ok("4m 命中延迟 ≤ 3 帧", int(near[1]) <= 3, "%d 帧" % int(near[1]))
	_ok("单发伤害 = 22", is_equal_approx(float(near[2]), 22.0), "%.1f" % float(near[2]))

	# —— 远距离：飞行帧数必须多于近距离 ——
	await _wait(0.6)
	pistol.call(&"reset_ammo")
	await _wait(0.1)
	z = _place_target(18.0)
	await _wait(0.15)
	var far: Array = await _fire_and_measure(pistol)
	_ok("18m 走弹道能命中", int(far[0]) == 1, "命中 %d 次" % int(far[0]))
	_ok("18m 飞行帧数 > 4m", int(far[1]) > int(near[1]),
		"4m=%d 帧 / 18m=%d 帧" % [int(near[1]), int(far[1])])
	# 18m / 380 = 47ms ≈ 2.8 帧 @60fps；按 60fps 折算的理论延迟做上下界校验
	_ok("18m 延迟与距离/初速吻合（2~8 帧）", int(far[1]) >= 2 and int(far[1]) <= 8,
		"%d 帧" % int(far[1]))

	# —— hitscan 回退：muzzle_velocity = 0 必须当帧结算 ——
	await _wait(0.6)
	pistol.call(&"reset_ammo")
	await _wait(0.1)
	var saved: float = float(pistol.data.muzzle_velocity)
	pistol.data.muzzle_velocity = 0.0
	z = _place_target(4.0)
	await _wait(0.15)
	var hs: Array = await _fire_and_measure(pistol)
	_ok("muzzle_velocity=0 时当帧命中（纯 hitscan）", int(hs[0]) == 1 and int(hs[1]) == 0,
		"命中 %d 次 / %d 帧" % [int(hs[0]), int(hs[1])])
	pistol.data.muzzle_velocity = saved

	# —— 切枪不冻结在飞的弹丸 ——
	# arsenal.equip 曾对旧枪 set_process(false)，会让弹丸冻在半空。
	await _wait(0.6)
	pistol.call(&"reset_ammo")
	await _wait(0.1)
	z = _place_target(14.0)
	await _wait(0.15)
	_hits.clear()
	_record = true
	pistol.pull_trigger()
	pistol.release_trigger()
	_player.call(&"_equip", 1)      # 开火后立刻切到霰弹枪
	for _i: int in 30:
		if not _hits.is_empty():
			break
		await get_tree().process_frame
	_record = false
	_ok("切枪后在飞的弹丸继续飞并命中", _hits.size() == 1, "命中 %d 次" % _hits.size())
	_player.call(&"_equip", 0)

	# —— 霰弹枪 8 颗弹丸各自走弹道 ——
	await _wait(0.5)
	shotgun.call(&"reset_ammo")
	_player.call(&"_equip", 1)
	await _wait(0.2)
	z = _place_target(3.0)
	await _wait(0.15)
	var sg: Array = await _fire_and_measure(shotgun)
	_ok("霰弹枪走弹道并命中", int(sg[0]) >= 1, "命中 %d 颗" % int(sg[0]))
	_ok("霰弹枪多弹丸（≥2 颗命中）", int(sg[0]) >= 2, "%d 颗" % int(sg[0]))
	_ok("霰弹枪总伤害 > 单颗 11", float(sg[2]) > 11.0, "%.1f" % float(sg[2]))
	_ok("霰弹枪命中延迟 > 0 帧", int(sg[1]) > 0, "%d 帧" % int(sg[1]))

## 用一个临时副本验证 validate() 会拦下过低初速（不污染真数据）
func _low_velocity_flagged(data: WeaponData) -> bool:
	var probe: WeaponData = data.duplicate() as WeaponData
	probe.muzzle_velocity = 50.0
	return not probe.validate().is_empty()
