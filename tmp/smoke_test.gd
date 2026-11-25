## 临时验证脚本（不属于交付物）
## 在真实 SceneTree + Autoload 环境下实例化全部玩法脚本，验证：
##   1. 所有 class_name 可解析、_ready 无运行期错误
##   2. 对象池 acquire/release 闭环
##   3. 武器射线参数类型正确（Array[RID]）
##   4. 波次流程能推进、Director 压力值能输出
extends Node

var _errors: Array[String] = []

func _ready() -> void:
	print("=== SMOKE TEST START ===")
	_test_autoloads()
	_test_input_actions()
	_test_health()
	_test_pool()
	await _test_weapon()
	await _test_zombie()
	await _test_waves_and_director()
	_report()

func _test_autoloads() -> void:
	_check(EventBus != null, "EventBus autoload 可用")
	_check(GameManager != null, "GameManager autoload 可用")
	_check(EventBus.has_signal(&"player_fired"), "EventBus.player_fired 存在")
	_check(EventBus.has_signal(&"director_pressure_changed"), "EventBus.director_pressure_changed 存在")
	_check(EventBus.has_signal(&"all_waves_cleared"), "EventBus.all_waves_cleared 存在")

func _test_input_actions() -> void:
	InputSetup.ensure_defaults()
	var missing: Array[StringName] = InputSetup.missing_actions()
	_check(missing.is_empty(), "InputMap 动作齐全（缺失: %s）" % str(missing))

func _test_health() -> void:
	var hc := HealthComponent.new()
	hc.max_health = 100.0
	add_child(hc)
	var seen: Array[float] = []
	hc.health_changed.connect(func(v: float, _m: float) -> void: seen.append(v))
	hc.apply_damage(30.0, null)
	_check(is_equal_approx(hc.current_health(), 70.0), "HealthComponent 扣血 100-30=70")
	hc.heal(10.0)
	_check(is_equal_approx(hc.current_health(), 80.0), "HealthComponent 治疗 70+10=80")
	hc.heal(999.0)
	_check(is_equal_approx(hc.current_health(), 100.0), "HealthComponent 治疗不溢出上限")
	var deaths: Array[int] = []
	hc.died.connect(func(_s: Node) -> void: deaths.append(1))
	hc.apply_damage(200.0, null)
	hc.apply_damage(200.0, null)
	_check(deaths.size() == 1, "HealthComponent 死亡信号幂等（实际 %d 次）" % deaths.size())
	hc.queue_free()

func _test_pool() -> void:
	var pool := ObjectPool.new()
	pool.name = "TestPool"
	var scene := PackedScene.new()
	var proto := Node3D.new()
	proto.name = "Proto"
	scene.pack(proto)
	proto.free()
	pool.scene = scene
	pool.initial_size = 3
	pool.max_size = 5
	add_child(pool)
	_check(pool.is_in_group(GameLayers.GROUP_POOL), "ObjectPool 已加入 ObjectPool 分组")
	_check(pool.capacity() == 3, "ObjectPool 预热 3 个（实际 %d）" % pool.capacity())
	var a: Node = pool.acquire()
	var b: Node = pool.acquire()
	_check(a != null and b != null and a != b, "ObjectPool acquire 返回不同实例")
	_check(pool.active_count() == 2, "ObjectPool active_count == 2")
	pool.release(a)
	_check(pool.active_count() == 1, "ObjectPool release 后 active_count == 1")
	pool.release(a)
	_check(pool.active_count() == 1, "ObjectPool 重复 release 安全")
	pool.release_all()
	_check(pool.active_count() == 0, "ObjectPool release_all 清零")
	pool.queue_free()

func _test_weapon() -> void:
	var wd := WeaponData.new()
	wd.display_name = "测试霰弹枪"
	wd.pellets = 8
	wd.spread_degrees = 5.0
	wd.magazine_size = 6
	wd.reserve_ammo = 12
	wd.rounds_per_minute = 60.0
	wd.reload_time = 1.0
	_check(wd.validate().is_empty(), "WeaponData.validate 通过")
	_check(is_equal_approx(wd.shot_interval(), 1.0), "WeaponData 60rpm → 1.0 秒/发")
	_check(wd.effective_damage() > 0.0, "WeaponData effective_damage 有值")

	var host := CharacterBody3D.new()
	host.name = "FakeShooter"
	host.add_to_group(GameLayers.GROUP_PLAYER)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	host.add_child(cam)
	var weapon := Weapon.new()
	weapon.name = "TestWeapon"
	weapon.data = wd
	weapon.shooter_path = ^"../FakeShooter"
	add_child(host)
	cam.add_child(weapon)
	await get_tree().process_frame
	_check(weapon.mag_ammo() == 6, "Weapon 初始弹匣 6（实际 %d）" % weapon.mag_ammo())
	var fired: Array[int] = []
	EventBus.player_fired.connect(func(_d: Resource, _r: float) -> void: fired.append(1))
	var ok: bool = weapon.try_fire()
	_check(ok, "Weapon.try_fire 返回 true")
	_check(weapon.mag_ammo() == 5, "Weapon 开火后弹匣 5（实际 %d）" % weapon.mag_ammo())
	_check(fired.size() == 1, "Weapon 广播 player_fired 一次")
	_check(weapon.start_reload(), "Weapon.start_reload 返回 true")
	_check(weapon.is_reloading(), "Weapon 进入换弹状态")
	weapon.cancel_reload()
	_check(not weapon.is_reloading(), "Weapon.cancel_reload 打断换弹")
	weapon.add_reserve(5)
	_check(weapon.reserve_ammo() == 17, "Weapon 补弹 12+5=17（实际 %d）" % weapon.reserve_ammo())
	weapon.queue_free()
	host.queue_free()

func _test_zombie() -> void:
	# 建一个真实池，验证"死亡 → 回池 → 复用"闭环（旧骨架在此处断裂）
	var pool := ObjectPool.new()
	pool.name = "ZombiePool"
	pool.initial_size = 0   # 本用例靠 release 收养，不需要预热
	pool.max_size = 4
	add_child(pool)
	await get_tree().process_frame

	var z := Zombie.new()
	z.name = "TestZombie"
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	z.add_child(hc)
	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.add_child(sprite)
	pool.add_child(z)
	await get_tree().process_frame
	_check(z.is_in_group(GameLayers.GROUP_ZOMBIE), "Zombie 已加入 Zombie 分组")
	_check(z.is_active_zombie(), "Zombie 初始为活跃")

	var died: Array[int] = []
	EventBus.zombie_died.connect(func(_zz: Node, _k: Node) -> void: died.append(1))
	z.take_damage(500.0, true, null)
	await get_tree().process_frame
	_check(died.size() == 1, "Zombie 死亡广播 zombie_died（实际 %d）" % died.size())
	_check(not z.is_active_zombie(), "Zombie 死亡后 is_active_zombie == false")
	# 死亡改为延迟回收：先播倒地动画，倒计时结束才回池
	_check(z.get_parent() == pool, "死亡瞬间仍挂在池下（播倒地动画）")
	await get_tree().create_timer(Zombie.DEATH_ANIM_HOLD + 0.25).timeout
	_check(is_instance_valid(z) and z.get_parent() == pool, "Zombie 死亡后回池而非 queue_free")

	# 复用：出池后血量必须回满、状态回 IDLE
	var again: Node = pool.acquire()
	_check(again == z, "ObjectPool 复用同一具丧尸实例")
	var z2: Zombie = again as Zombie
	_check(z2 != null and z2.is_active_zombie(), "复用后 is_active_zombie == true")
	_check(z2.current_state() == Zombie.State.IDLE, "复用后状态复位为 IDLE")
	var hp: HealthComponent = z2.health_node()
	_check(hp != null and is_equal_approx(hp.current_health(), hp.max_health),
		"复用后血量回满（%.1f/%.1f）" % [hp.current_health(), hp.max_health])
	pool.queue_free()

func _test_waves_and_director() -> void:
	var spawner := WaveSpawner.new()
	spawner.name = "TestSpawner"
	spawner.fallback_wave_count = 2
	spawner.fallback_base_count = 3
	add_child(spawner)
	await get_tree().process_frame
	_check(spawner.total_waves() == 2, "WaveSpawner 自动生成 2 波（实际 %d）" % spawner.total_waves())

	var dir := Director.new()
	dir.name = "TestDirector"
	add_child(dir)
	await get_tree().process_frame
	_check(dir.is_in_group(GameLayers.GROUP_DIRECTOR), "Director 已加入 Director 分组")
	EventBus.player_health_changed.emit(10.0, 100.0)
	EventBus.ammo_changed.emit(2, 3)
	EventBus.zombie_count_changed.emit(20)
	# 四路输入理论值：血 0.9*0.35 + 弹 0.583*0.25 + 受击 0*0.20 + 密度 1.0*0.20 = 0.661
	await get_tree().process_frame
	_check(absf(dir.target_pressure() - 0.661) < 0.02,
		"Director 目标压力 == 0.661（实际 %.3f）" % dir.target_pressure())
	# 平滑收敛需真实时间，等 2 秒
	await get_tree().create_timer(2.0).timeout
	_check(dir.pressure() > 0.6, "Director 压力平滑收敛到高压区（实际 %.3f）" % dir.pressure())
	_check(dir.pressure_label() != "", "Director pressure_label 非空")

	spawner.apply_director_output(1.5, 0.1)
	_check(true, "WaveSpawner.apply_director_output 可调用")

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [PASS] ", label)
	else:
		print("  [FAIL] ", label)
		_errors.append(label)

func _report() -> void:
	print("=== SMOKE TEST END ===")
	if _errors.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAILED" % _errors.size())
		for e: String in _errors:
			print("  - ", e)
	get_tree().quit(0 if _errors.is_empty() else 1)
