## 临时验证：60 只丧尸同屏压力测试（不属于交付物）
## 对应 PDF Phase 1 硬指标："丧尸/子弹/特效全部对象池化，同屏 60 只稳定 60 帧"。
## 用 headless 模式测 CPU 侧（AI 状态机 + 分离力 + 池调度）每帧耗时；
## 渲染耗时需在有窗口模式下另测，此处只断言逻辑帧预算。
extends Node

const TARGET_COUNT := 60
const SAMPLE_FRAMES := 300

var _errors: Array[String] = []
var _zombies: Array[Zombie] = []
var _pool: ObjectPool
var _frame_times: Array[float] = []

func _ready() -> void:
	print("=== STRESS TEST START (target %d zombies) ===" % TARGET_COUNT)
	await _setup()
	await _warmup()
	await _measure()
	_report()

func _setup() -> void:
	# 场景原型：一只完整丧尸（Collision + Health + Sprite + Weakspot）
	var proto := CharacterBody3D.new()
	proto.name = "ZombieProto"
	var script: Script = load("res://scripts/enemies/zombie.gd")
	proto.set_script(script)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.7
	capsule.radius = 0.35
	shape.shape = capsule
	proto.add_child(shape)

	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = 100.0
	proto.add_child(hc)

	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	proto.add_child(sprite)

	var weak := Area3D.new()
	weak.name = "Weakspot"
	weak.add_to_group(GameLayers.GROUP_WEAKSPOT)
	var weak_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	weak_shape.shape = sphere
	weak.add_child(weak_shape)
	proto.add_child(weak)

	var packed := PackedScene.new()
	var err: int = packed.pack(proto)
	_check(err == OK, "丧尸原型 PackedScene 打包成功（err=%d）" % err)
	proto.free()

	_pool = ObjectPool.new()
	_pool.name = "StressPool"
	_pool.scene = packed
	_pool.initial_size = TARGET_COUNT
	_pool.max_size = TARGET_COUNT * 2
	add_child(_pool)
	await get_tree().process_frame

	# 一个假玩家作为追击目标，放在圆心
	var player := CharacterBody3D.new()
	player.name = "FakePlayer"
	player.add_to_group(GameLayers.GROUP_PLAYER)
	add_child(player)
	player.global_position = Vector3.ZERO

	# 一个假摄像机，让 _update_sprite_facing 走真实分支
	var cam := Camera3D.new()
	cam.name = "StressCam"
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 8, 12)

	# 60 只围一圈出池
	for i: int in TARGET_COUNT:
		var z: Node = _pool.acquire()
		if z == null:
			_check(false, "第 %d 只丧尸出池失败" % i)
			return
		var z3d: Zombie = z as Zombie
		var angle: float = TAU * float(i) / float(TARGET_COUNT)
		z3d.global_position = Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0)
		_zombies.append(z3d)
	_check(_zombies.size() == TARGET_COUNT, "池化出 %d 只丧尸（实际 %d）"
		% [TARGET_COUNT, _zombies.size()])
	_check(_pool.active_count() == TARGET_COUNT, "ObjectPool.active_count == %d" % TARGET_COUNT)

func _warmup() -> void:
	# 预热 30 帧，让分离力与寻路进入稳态
	for _i: int in 30:
		await get_tree().physics_frame

func _measure() -> void:
	# 关键：不能用 await physics_frame 的间隔计时——headless 下物理帧间隔恒为
	# 1/physics_ticks_per_second（16.67ms），量到的是"帧间隔"而非"物理耗时"。
	# 必须读 Godot 官方监控 TIME_PHYSICS_PROCESS（上一帧物理处理实际耗时，秒）。
	_frame_times.clear()
	for _i: int in SAMPLE_FRAMES:
		await get_tree().physics_frame
		var sec: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_frame_times.append(sec * 1000.0)
	# 去掉前 10% 抖动样本
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	var cut: int = int(float(sorted.size()) * 0.1)
	var trimmed: Array[float] = sorted.slice(cut)
	var total: float = 0.0
	for t: float in trimmed:
		total += t
	var avg: float = total / float(trimmed.size())
	var p95: float = trimmed[int(float(trimmed.size()) * 0.95)]
	var worst: float = trimmed[trimmed.size() - 1]
	print("  物理处理耗时: avg=%.3f ms  p95=%.3f ms  worst=%.3f ms（预算 16.67 ms/帧）"
		% [avg, p95, worst])
	# 16.67ms 是 60fps 一帧总预算，物理侧应留一半以上给渲染与脚本
	_check(avg < 8.0, "60 只丧尸物理处理平均 < 8 ms（实际 %.3f ms）" % avg)
	_check(p95 < 16.0, "60 只丧尸物理处理 p95 < 16 ms（实际 %.3f ms）" % p95)
	# 状态正确性：60 只都应在 CHASE 或 ATTACK
	var chasing: int = 0
	for z: Zombie in _zombies:
		if z.current_state() == Zombie.State.CHASE or z.current_state() == Zombie.State.ATTACK:
			chasing += 1
	_check(chasing == TARGET_COUNT, "%d 只丧尸全部进入追击/攻击态（实际 %d）"
		% [TARGET_COUNT, chasing])

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [PASS] ", label)
	else:
		print("  [FAIL] ", label)
		_errors.append(label)

func _report() -> void:
	print("=== STRESS TEST END ===")
	if _errors.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAILED" % _errors.size())
		for e: String in _errors:
			print("  - ", e)
	get_tree().quit(0 if _errors.is_empty() else 1)
