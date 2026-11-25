## 端到端探针：把 main.tscn 拉起来，真实推进游戏循环，逐项核对契约。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame --headless res://tmp/probe_runner.tscn
extends Node

var _pass := 0
var _fail := 0
var _main: Node
var _player: Node
var _spawner: Node

func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label, ("  [" + detail + "]") if detail != "" else "")
	else:
		_fail += 1
		print("  FAIL  ", label, ("  [" + detail + "]") if detail != "" else "")

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	print("=== E2E PROBE ===")
	await _run()
	print("=== RESULT pass=%d fail=%d ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await _wait(0.4)

	_player = _main.get_node_or_null("Player")
	_spawner = _main.get_node_or_null("WaveSpawner")
	_ok("Player 存在", _player != null)
	_ok("WaveSpawner 存在", _spawner != null)
	if _player == null or _spawner == null:
		return

	# —— 节点契约 ——
	_ok("Player.HealthComponent", _player.get_node_or_null("HealthComponent") != null)
	_ok("Player.CameraRig/Camera3D", _player.get_node_or_null("CameraRig/Camera3D") != null)
	var mount := _player.get_node_or_null("CameraRig/Camera3D/WeaponMount")
	_ok("Player.WeaponMount", mount != null)
	if mount != null:
		_ok("Weapon 槽位=2", mount.get_child_count() == 2, str(mount.get_child_count()))
		var pistol: Node = mount.get_child(0)
		_ok("槽位0 是 Weapon 且 data 非空", pistol.get(&"data") != null,
			str(pistol.get(&"data").display_name if pistol.get(&"data") != null else "null"))
		_ok("Pistol.shooter_path 可解析", pistol.get_node_or_null(pistol.get(&"shooter_path")) == _player)

	# —— 游戏状态 ——
	_ok("GameState=PLAYING", GameManager.state() == GameManager.GameState.PLAYING,
		str(GameManager.state()))
	_ok("Input 动作齐全", InputSetup.missing_actions().is_empty(),
		str(InputSetup.missing_actions()))
	_ok("Input 动作有绑定", InputSetup.unbound_actions().is_empty(),
		str(InputSetup.unbound_actions()))

	# —— 波次推进 ——
	# 注意：分组里同时包含池中休眠实例，必须用 is_active_zombie() 过滤
	var phase0: int = _spawner.current_phase()
	await _wait(4.5)
	var alive: int = 0
	var z: Node = null
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if n.is_active_zombie():
			alive += 1
			if z == null:
				z = n
	_ok("4.5s 内已进入刷怪/清场阶段",
		_spawner.current_phase() == 2 or _spawner.current_phase() == 3,
		"phase %d -> %d" % [phase0, _spawner.current_phase()])
	_ok("已有活跃丧尸", alive > 0, "active=%d" % alive)
	if z != null:
		_ok("Zombie.HealthComponent", z.get_node_or_null("HealthComponent") != null)
		_ok("Zombie.Sprite3D 有贴图", z.get_node_or_null("Sprite3D") != null
			and z.get_node("Sprite3D").texture != null)
		_ok("Zombie 入组 Weakspot 子节点存在",
			z.get_node_or_null("Weakspot") != null
			and z.get_node("Weakspot").is_in_group(GameLayers.GROUP_WEAKSPOT))
		_ok("Zombie 池化基准值已记录",
			float(z.get(&"_base_move_speed")) > 0.0,
			"base_speed=%.2f" % float(z.get(&"_base_move_speed")))

	# —— 射击 ——
	var pistol2: Node = mount.get_child(0)
	var mag_before: int = pistol2.mag_ammo()
	var hp_before: float = -1.0
	var target: Node = null
	# 把一只丧尸搬到玩家正前方 4 米，保证射线能命中
	var cam: Camera3D = _player.get_node("CameraRig/Camera3D")
	if z != null:
		# 胶囊中心必须落在摄像机水平线上，否则射线从脚底掠过。冻结物理防止它掉落/追击。
		z.set_physics_process(false)
		var fwd: Vector3 = -cam.global_transform.basis.z
		z.global_position = cam.global_position + fwd * 4.0 - Vector3(0.0, 0.9, 0.0)
		target = z
		await _wait(0.1)
		hp_before = z.health_node().current_health()
	pistol2.pull_trigger()
	await _wait(0.25)
	_ok("开火消耗弹药", pistol2.mag_ammo() < mag_before,
		"mag %d -> %d" % [mag_before, pistol2.mag_ammo()])
	if target != null and hp_before >= 0.0:
		var hp_after: float = target.health_node().current_health()
		_ok("射线命中丧尸扣血", hp_after < hp_before,
			"hp %.1f -> %.1f" % [hp_before, hp_after])
	pistol2.release_trigger()

	# —— 换弹 ——
	var started: bool = pistol2.start_reload()
	_ok("start_reload 返回 true", started)
	await _wait(1.6)
	_ok("换弹后弹匣填满", pistol2.mag_ammo() == int(pistol2.data.magazine_size),
		"mag=%d" % pistol2.mag_ammo())

	# —— 池化数值不膨胀：连续两次"出池 + 难度乘数"后必须回到基准 ——
	if target != null:
		var base_speed: float = float(target.get(&"_base_move_speed"))
		var base_hp: float = float(target.get(&"_base_max_health"))
		_ok("基准值等于场景默认", is_equal_approx(base_speed, 2.4) and is_equal_approx(base_hp, 100.0),
			"base speed=%.2f hp=%.1f" % [base_speed, base_hp])
		var trace: Array[String] = []
		for round_i: int in 3:
			target._on_pool_acquired()
			target.move_speed *= 1.2
			target.max_health *= 1.2
			trace.append("%.2f" % target.move_speed)
		# 第四轮不再乘，验证还原生效
		target._on_pool_acquired()
		_ok("三次难度乘数后仍能还原到基准",
			is_equal_approx(target.move_speed, base_speed)
			and is_equal_approx(target.max_health, base_hp),
			"累积过程 %s → 还原 %.2f/%.1f" % ["→".join(trace), target.move_speed, target.max_health])
		target.set_physics_process(true)

	# —— 导演 ——
	var director: Node = _main.get_node_or_null("Director")
	_ok("Director 存在", director != null)
	if director != null:
		await _wait(0.5)
		_ok("Director 压力值在 0..1", director.pressure() >= 0.0 and director.pressure() <= 1.0,
			"%.2f (%s)" % [director.pressure(), director.pressure_label()])

	# —— 近战攻击链路：把一只活丧尸放到贴脸距离，等它咬 ——
	# 不依赖"4.5s 内自然跑到玩家身边"——刷怪点最近 8 米、速度 2.4m/s，需要 3.3s 以上，
	# 期间还在持续出怪，自然接触时间不可控。直接构造接触才是一次确定的验收。
	var hc: Node = _player.get_node("HealthComponent")
	var biter: Node = null
	for n: Node in get_tree().get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if n.is_active_zombie() and n != target:
			biter = n
			break
	_ok("存在第二只活丧尸用于近战测试", biter != null)
	if biter != null:
		biter.set_physics_process(true)
		var ppos: Vector3 = _player.global_position
		biter.global_position = ppos + Vector3(0.0, 0.0, 1.1)
		await _wait(2.0)
		var taken: float = hc.max_health - hc.current_health()
		_ok("丧尸近战咬到玩家", taken > 0.0,
			"玩家掉血 %.1f → hp=%.1f" % [taken, hc.current_health()])
		_ok("zombie_died 计数与实际一致",
			_spawner.get(&"_alive") >= 0,
			"spawner._alive=%d" % int(_spawner.get(&"_alive")))

	# —— 玩家死亡流程 ——
	# 清场：否则 999 伤害会被 hit_invulnerable_time 无敌帧吞掉，测不到死亡
	_spawner.stop()
	await _wait(0.6)
	# 复位玩家再测受伤：上面的近战用例里玩家可能已被多只丧尸咬死
	# （第一章同屏上限 8，2 秒内足以打空 100 血），此时 take_damage 因 _is_dead
	# 直接返回 0，会把"玩家已死"误判成"受伤扣血功能坏了"。
	# 注意不能用 heal()：heal 只加血，不复位 _is_dead 标志，is_alive() 仍为 false。
	_player.reset_player()
	await _wait(0.4)
	# hc 是 Node 静态类型，脚本属性必须走 get()：
	# 直接写 hc.max_health 会被当成方法调用 → "Nonexistent function 'max_health'"，中断后续全部用例。
	var hp_max: float = float(hc.get(&"max_health"))
	_ok("复位后玩家存活且满血", hc.is_full() and _player.is_alive(),
		"hp=%.1f/%.1f alive=%s" % [hc.current_health(), hp_max,
			str(_player.is_alive())])
	var hp0: float = hc.current_health()
	var dealt1: float = _player.take_damage(10.0, false, null)
	_ok("玩家受伤扣血", dealt1 > 0.0 and hc.current_health() < hp0,
		"dealt=%.1f hp=%.1f" % [dealt1, hc.current_health()])
	await _wait(0.5)
	var dealt2: float = _player.take_damage(999.0, false, null)
	await _wait(0.4)
	_ok("玩家死亡进入 DEAD", GameManager.state() == GameManager.GameState.DEAD,
		"dealt=%.1f hp=%.1f state=%d" % [dealt2, hc.current_health(), GameManager.state()])

	# —— 重开 ——
	GameManager.restart_level()
	await _wait(0.6)
	_ok("重开后回到 PLAYING", GameManager.state() == GameManager.GameState.PLAYING,
		str(GameManager.state()))
	_ok("重开后玩家满血", _player.get_node("HealthComponent").is_full())
	_ok("重开后波次归零", _spawner.current_wave() == 0,
		"wave=%d" % _spawner.current_wave())
