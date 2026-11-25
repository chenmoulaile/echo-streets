## 武器射线解算层：散布采样 / 射线投射 / 命中归类。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   weapon.gd 在补齐弹丸散布、弱点判定、金属判定后涨到 327 行，超红线。
##   职责切分：weapon.gd 管"状态机"（弹药、冷却、换弹、连发节奏），
##   本文件管"一发子弹打出去之后发生什么" —— 纯函数，不持有状态。
##   这样两侧都能独立演进：加新命中反馈不用碰换弹逻辑，反之亦然。
## 设计: 全部 static 且显式传参（不读 weapon 的成员），便于单元测试与复用。
## 两条命中路径共用同一个 resolve_hit：
##   - 瞬时（muzzle_velocity == 0）：fire_pellet 一次投满射程。
##   - 真实初速（muzzle_velocity > 0）：weapon_projectile.gd 逐帧推进后调 resolve_hit。
##   拆成两个入口而不是在 fire_pellet 里加分支，是为了让「瞬时」路径保持零分配。
extends RefCounted

## 在方向向量 dir 上按均匀圆盘加随机锥形散布。spread_degrees = 0 时零开销直射。
## 存在理由：真实初速弹道在开火瞬间就要定死方向（飞行途中不能再抖），
## 那时手上只有摄像机 basis 解出来的 forward，没有 basis 可传。
static func apply_spread_from(dir: Vector3, spread_degrees: float) -> Vector3:
	var forward: Vector3 = dir.normalized()
	if spread_degrees <= 0.0:
		return forward
	# 构造一组与 forward 正交的基，用于在锥面上取偏移
	var up_ref: Vector3 = Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var side: Vector3 = forward.cross(up_ref).normalized()
	var up: Vector3 = side.cross(forward).normalized()
	var rad: float = deg_to_rad(spread_degrees)
	# 均匀圆盘采样：sqrt 保证面积均匀，避免中心过密
	var r: float = sqrt(randf()) * rad
	var theta: float = randf() * TAU
	var offset: Vector3 = side * (cos(theta) * r) + up * (sin(theta) * r)
	return (forward + offset).normalized()

## 在 basis 的 -Z 轴上加随机锥形散布。spread_degrees = 0 时零开销直射。
static func apply_spread(basis: Basis, spread_degrees: float) -> Vector3:
	return apply_spread_from(-basis.z, spread_degrees)

## 打出一颗弹丸：投射射线、结算伤害、广播命中事件。
## world 由调用方给（weapon 用 get_world_3d()），避免本层依赖节点树。
## exclude 必须是 Array[RID] —— Godot 4 的 PhysicsRayQueryParameters3D
##   要求 RID 数组，传 Node 会在运行时抛 "Invalid type in array"。
## spread_scale：开镜时收小散布。默认 1.0 保证既有调用零改动。
static func fire_pellet(world: World3D, data: WeaponData, origin: Vector3,
		basis: Basis, exclude: Array[RID], shooter: Node3D,
		spread_scale: float = 1.0) -> void:
	var dir: Vector3 = apply_spread(basis, data.spread_degrees * maxf(spread_scale, 0.0))
	var to: Vector3 = origin + dir * data.max_range
	var query := PhysicsRayQueryParameters3D.create(
		origin, to, GameLayers.MASK_HITSCAN, exclude
	)
	query.collide_with_areas = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	resolve_hit(hit, data.effective_damage(), data.weakspot_multiplier, shooter)

## 命中结算：弱点判定 → 找受击目标 → 扣血 → 广播。
## 抽成独立入口是为了让「瞬时命中」与「飞行弹丸命中」走完全相同的结算，
## 否则两条路径的伤害/事件早晚会漂移（改一处忘另一处）。
## damage 是**未乘弱点倍率**的基础伤害 —— 倍率在这里乘，调用方不要预乘。
static func resolve_hit(hit: Dictionary, damage: float, weakspot_multiplier: float,
		shooter: Node3D) -> void:
	var collider: Object = hit.get("collider") as Object
	var point: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	var weakspot: bool = is_weakspot(collider)
	var target: Node = resolve_damage_target(collider)
	if target != null:
		var dmg: float = damage
		if weakspot:
			dmg *= weakspot_multiplier
		target.call(&"take_damage", dmg, weakspot, shooter)
		EventBus.zombie_hit.emit(target, dmg, weakspot)
	else:
		EventBus.bullet_impact.emit(point, normal, is_metal(collider))

## 命中体是否属于弱点（爆头）区域。弱点是一个 Area3D，在 Weakspot 组里。
static func is_weakspot(collider: Object) -> bool:
	var node: Node = collider as Node
	if node == null:
		return false
	return node.is_in_group(GameLayers.GROUP_WEAKSPOT)

## 命中体可能是 Weakspot Area，真正的受击目标在其父级链上。
static func resolve_damage_target(collider: Object) -> Node:
	var node: Node = collider as Node
	while node != null:
		if node.has_method(&"take_damage"):
			return node
		node = node.get_parent()
	return null

## 命中体是否是金属表面（决定火花特效的材质分支）。
static func is_metal(collider: Object) -> bool:
	var node: Node = collider as Node
	if node == null:
		return false
	return node.is_in_group(&"Metal")
