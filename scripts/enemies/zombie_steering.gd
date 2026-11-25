## 丧尸转向/感知的纯计算工具（无状态，全部 static）
## class_name: ZombieSteering
## 挂载节点类型: 不挂载 —— 纯静态工具类（extends RefCounted），由 Zombie 调用
## 依赖信号: 无
## 节点路径假设: 无（不访问节点树之外的任何路径；所有节点由调用方传入）
## 抽离理由:
##   PDF 红线"单文件不超过 300 行"，zombie.gd 承载状态机 + 移动 + 感知 + 池化
##   四项职责已 345 行。把"给定场景计算出一个方向/一个布尔"的纯函数搬到这里，
##   Zombie 只保留状态推进与生命周期，两侧都可独立单测。
class_name ZombieSteering
extends RefCounted

## 分离力半径内同群的推力累加（不含自身）。
## 让 60 只丧尸围堵时不叠在一点，天然形成包抄弧 —— PDF「围堵包抄，高密度」。
static func separation(
		self_pos: Vector3,
		self_node: Node,
		neighbors: Array[Node],
		radius: float,
	) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	if radius <= 0.0:
		return push
	var radius_sq: float = radius * radius
	for other: Node in neighbors:
		if other == null or other == self_node:
			continue
		var other_3d: Node3D = other as Node3D
		if other_3d == null:
			continue
		var offset: Vector3 = self_pos - other_3d.global_position
		offset.y = 0.0
		var d_sq: float = offset.length_squared()
		if d_sq > 0.0001 and d_sq < radius_sq:
			push += offset.normalized() * (1.0 - sqrt(d_sq) / radius)
	return push

## 追击方向：优先 NavigationAgent3D 的下一路点，否则直线逼近；
## 叠加分离力后归一化。返回零向量表示"原地不动"。
static func chase_direction(
		agent: NavigationAgent3D,
		self_pos: Vector3,
		target_pos: Vector3,
		separation_push: Vector3,
		separation_strength: float,
	) -> Vector3:
	var flat: Vector3 = target_pos - self_pos
	flat.y = 0.0
	var dist: float = flat.length()
	var dir: Vector3 = flat / maxf(dist, 0.001)
	# 有导航网格时走 A* 路径；agent 不在树里（池化预热期）则退回直线
	if agent != null and agent.is_inside_tree():
		agent.target_position = target_pos
		var next_point: Vector3 = agent.get_next_path_position()
		var nav_dir: Vector3 = next_point - self_pos
		nav_dir.y = 0.0
		if nav_dir.length_squared() > 0.01:
			dir = nav_dir.normalized()
	dir += separation_push * separation_strength
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()

## 目标是否有 is_alive() 且为真。没有该方法的节点视为存活，
## 这样任意 Player 实现（含测试替身）都能被追击。
## 修复旧骨架：直接 _target.is_alive() 对 Node3D 静态类型调用会在解析期报错。
static func node_alive(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.has_method(&"is_alive"):
		return bool(node.call(&"is_alive"))
	return true

## 视线检测：从自身胸口到目标胸口，命中自身则忽略，命中目标则可见。
static func has_line_of_sight(
		world: World3D,
		self_rid: RID,
		from: Vector3,
		to: Vector3,
		target: Node,
		mask: int,
	) -> bool:
	if world == null or target == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	# Godot 4 要求 Array[RID]；旧骨架传 Node 会运行时报错
	query.exclude = [self_rid]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

## billboard 精灵不转向 —— 只按"目标在摄像机右向量的哪一侧"决定 flip_h。
## 与 PDF「Sprite3D 纸板人始终面向摄像机」一致：绝不对 Sprite3D 做 look_at。
static func sprite_flip_h(
		sprite: Sprite3D,
		camera: Camera3D,
		self_pos: Vector3,
		target_pos: Vector3,
	) -> void:
	if sprite == null or camera == null:
		return
	var to_target: Vector3 = target_pos - self_pos
	var right: Vector3 = camera.global_transform.basis.x
	sprite.flip_h = to_target.dot(right) < 0.0

## 水平速度朝 desired 靠拢（帧率无关：rate * delta）。
## 修复旧骨架 velocity.x = move_toward(velocity.x, 0, move_speed) —— 每帧固定
## 减速度既与帧率绑定，又把 move_speed 当减速度用量纲错误。
static func steer_horizontal(velocity: Vector3, desired: Vector3, rate: float, delta: float) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(desired, rate * delta)
	return Vector3(horizontal.x, velocity.y, horizontal.z)

## 重力累加到 velocity.y（落地时由 move_and_slide 归零）
static func apply_gravity(velocity: Vector3, on_floor: bool, scale: float, delta: float) -> Vector3:
	if on_floor:
		return velocity
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	return Vector3(velocity.x, velocity.y - g * scale * delta, velocity.z)
