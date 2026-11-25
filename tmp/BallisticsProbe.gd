## 弹道专项探针：验证 muzzle_velocity 的两条命中路径都成立。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/ballistics_runner.tscn
## 为什么单独一个探针而不是塞进 Probe.gd：
##   Probe.gd 的射击断言只看"最终有没有掉血"，无法区分"同一帧掉血"（hitscan）
##   和"隔几帧掉血"（弹道）。初速改动的核心契约恰恰就是延迟，必须精确采样。
## 为什么用**毫秒**而不是帧号当判据（踩过的坑）：
##   本机渲染帧率不稳定（实测 21~60fps 波动）。18 米 / 380m/s 只有 47ms，
##   掉到 21fps 时单帧 47ms —— 4 米和 18 米的飞行时间会落进同一帧，
##   用"帧数"作断言必然假失败。改用 Time.get_ticks_usec() 量真实耗时。
## 为什么用 EventBus.zombie_hit 计数而不是读丧尸血量：
##   血量会被多次测试累积扣光，一旦死亡就被对象池回收，后续断言全部失真。
##   信号里直接带 damage 与时刻，一次开火命中几颗、延迟多久都能精确读出。
extends Node

var _pass := 0
var _fail := 0
var _main: Node
var _player: Node
## 每次开火前清空。元素 = [命中时刻 usec, 伤害, 是否弱点]
var _hits: Array = []
var _record: bool = false
var _t0: int = 0

func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label, ("  [" + detail + "]") if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, ("  [" + detail + "]") if detail != "" else "")

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _on_zombie_hit(_zombie: Node, damage: float, is_weakspot: bool) -> void:
	if _record:
		_hits.append([Time.get_ticks_usec(), damage, is_weakspot])

func _ready() -> void:
	print("=== BALLISTICS PROBE ===")
	EventBus.zombie_hit.connect(_on_zombie_hit)
	await _run()
	print("=== RESULT pass=%d fail=%d ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

## 把一只活丧尸摆到玩家正前方 dist 米处并冻结物理，回满血，返回该丧尸。
## 其余活跃丧尸全部挪到洼地下面：它们本来会自己走过来，导致"命中的那 1 次"
## 可能来自一只路过的小怪，延迟度量就完全失真（实测过：49m 那次命中的是走近的散户）。
func _place_target(dist: float) -> Node:
	var cam: Camera3D = _player.get_node("CameraRig/Camera3D")
	var chosen: Node = null
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if not n.is_active_zombie():
			continue
		n.set_physics_process(false)
		var hc: Node = n.get_node_or_null("HealthComponent")
		if hc != null:
			hc.call(&"reset_health")
		if chosen == null:
			chosen = n
			var fwd: Vector3 = -cam.global_transform.basis.z
			n.global_position = cam.global_position + fwd * dist - Vector3(0.0, 0.9, 0.0)
		else:
			n.global_position = Vector3(0.0, -200.0, 0.0)
	return chosen

## 纯数学层验证「延迟 = 距离 / 初速」：
##   advance(world, delta) 每帧推进 min(speed*delta, 剩余射程) 米。
## 起点放在 y=500 高空、朝正上方飞 —— 那里没有任何几何体，射程耗尽才结束，
## 于是 travelled 与调用次数都是确定的，不受渲染帧率与场景内容影响的干扰。
func _probe_advance_math() -> void:
	var base: WeaponData = load("res://data/weapon_pistol.tres") as WeaponData
	var data: WeaponData = base.duplicate() as WeaponData
	data.muzzle_velocity = 60.0        # 60 m/s
	data.max_range = 10.0              # 10 米射程
	data.spread_degrees = 0.0          # 零散布，方向必须精确朝上
	var world: World3D = _main.get_world_3d()
	var far_up := Vector3(0.0, 500.0, 0.0)
	var p: WeaponProjectile = WeaponProjectile.spawn(
		data, far_up, Vector3.UP, null, [], 1.0)
	_ok("弹丸出膛 travelled = 0", is_zero_approx(p.travelled), "%.3f" % p.travelled)

	var step := 1.0 / 60.0
	var calls: int = 0
	var done_at: int = -1
	while calls < 200:
		calls += 1
		if p.advance(world, step):
			done_at = calls
			break
	_ok("60m/s 飞 10m 正好 10 帧结束", done_at == 10, "第 %d 帧结束" % done_at)
	_ok("耗尽时 travelled = max_range", is_equal_approx(p.travelled, 10.0),
		"%.3f m" % p.travelled)
	_ok("结束时 advance 继续返回 true（幂等）", p.advance(world, step))

	# 同样 10 米、速度翻倍 → 帧数减半
	data.muzzle_velocity = 120.0
	var p2: WeaponProjectile = WeaponProjectile.spawn(
		data, far_up, Vector3.UP, null, [], 1.0)
	var calls2: int = 0
	var done2: int = -1
	while calls2 < 200:
		calls2 += 1
		if p2.advance(world, step):
			done2 = calls2
			break
	_ok("120m/s 飞 10m 帧数减半（5 帧）", done2 == 5, "第 %d 帧结束" % done2)
	_ok("速度与帧数成反比", done2 > 0 and done_at == done2 * 2,
		"60m/s=%d 帧 / 120m/s=%d 帧" % [done_at, done2])


## 开一枪，记录命中信号。返回 [命中数, 首命中延迟 ms（-1 = 未命中）, 总伤害]
func _fire_and_measure(weapon: Node, max_wait_ms: int = 400) -> Array:
	_hits.clear()
	_record = true
	_t0 = Time.get_ticks_usec()
	weapon.pull_trigger()
	weapon.release_trigger()
	var deadline: int = _t0 + max_wait_ms * 1000
	while _hits.is_empty() and Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
	# 霰弹枪 8 颗弹丸可能不同帧结算，再收 100ms
	var gather: int = Time.get_ticks_usec() + 100000
	while Time.get_ticks_usec() < gather:
		await get_tree().process_frame
	_record = false
	var total: float = 0.0
	for h: Array in _hits:
		total += float(h[1])
	var delay_ms: int = -1
	if not _hits.is_empty():
		delay_ms = int((int(_hits[0][0]) - _t0) / 1000)
	return [_hits.size(), delay_ms, total]

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

	# —— 弹道路径：近距离必须有非零延迟 ——
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
	# 4m / 380m/s = 10.5ms。渲染帧 16~47ms，所以实测延迟是「一帧」，>0 即可。
	_ok("4m 命中延迟 > 0ms（不是当帧 hitscan）", int(near[1]) > 0, "%d ms" % int(near[1]))
	_ok("单发伤害 = 22", is_equal_approx(float(near[2]), 22.0), "%.1f" % float(near[2]))

	# —— 远距离：延迟必须与距离成比例 ——
	await _wait(0.6)
	pistol.call(&"reset_ammo")
	await _wait(0.1)
	z = _place_target(18.0)
	await _wait(0.15)
	var far: Array = await _fire_and_measure(pistol)
	_ok("18m 走弹道能命中", int(far[0]) == 1, "命中 %d 次" % int(far[0]))
	# 18m / 380m/s = 47ms。掉帧时会和 4m 同帧，所以只能断言「不短于理论值的一半」。
	var theory_ms: float = 18.0 / 380.0 * 1000.0
	_ok("18m 延迟不短于理论值 47ms 的一半", float(far[1]) >= theory_ms * 0.5,
		"实测 %d ms / 理论 %.1f ms" % [int(far[1]), theory_ms])
	_ok("18m 延迟 ≥ 4m 延迟", int(far[1]) >= int(near[1]),
		"4m=%d ms / 18m=%d ms" % [int(near[1]), int(far[1])])

	# —— 49m 远射：改用「纯数学推进」验证，不用真实场景 ——
	# 原因：ch01 大堂只有 22x46 米，49 米已经在大堂外面，射线撞墙不命中；
	# 而剩下的活跃丧尸会自己走过来，"命中的那 1 次"根本不是被摆过去的目标。
	# 距离/初速的线性关系属于数学契约，在高空无几何处验最干净。
	_probe_advance_math()

	# —— hitscan 回退：muzzle_velocity = 0 必须当帧结算 ——
	await _wait(0.6)
	pistol.call(&"reset_ammo")
	await _wait(0.1)
	var saved: float = float(pistol.data.muzzle_velocity)
	pistol.data.muzzle_velocity = 0.0
	z = _place_target(4.0)
	await _wait(0.15)
	var hs: Array = await _fire_and_measure(pistol)
	# hitscan 在同一帧内完成，elapsed 只剩函数调用开销，远小于一帧 16ms
	_ok("muzzle_velocity=0 时当帧命中（纯 hitscan）", int(hs[0]) == 1 and int(hs[1]) < 16,
		"命中 %d 次 / %d ms" % [int(hs[0]), int(hs[1])])
	pistol.data.muzzle_velocity = saved

	# —— 切枪不冻结在飞的弹丸 ——
	# arsenal.equip 曾对旧枪 set_process(false)，会让弹丸冻在半空。
	await _wait(0.6)
	pistol.call(&"reset_ammo")
	await _wait(0.1)
	z = _place_target(30.0)
	await _wait(0.15)
	_hits.clear()
	_record = true
	pistol.pull_trigger()
	pistol.release_trigger()
	_player.call(&"_equip", 1)      # 开火后立刻切到霰弹枪
	var sw_deadline: int = Time.get_ticks_usec() + 400000
	while _hits.is_empty() and Time.get_ticks_usec() < sw_deadline:
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
	_ok("霰弹枪命中延迟 > 0ms", int(sg[1]) > 0, "%d ms" % int(sg[1]))

## 用一个临时副本验证 validate() 会拦下过低初速（不污染真数据）
func _low_velocity_flagged(data: WeaponData) -> bool:
	var probe: WeaponData = data.duplicate() as WeaponData
	probe.muzzle_velocity = 50.0
	return not probe.validate().is_empty()
