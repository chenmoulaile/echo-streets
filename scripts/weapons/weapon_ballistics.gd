## 武器射线解算层：散布采样 / 射线投射 / 命中归类。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   weapon.gd 在补齐弹丸散布、弱点判定、金属判定后涨到 327 行，超红线。
##   职责切分：weapon.gd 管"状态机"（弹药、冷却、换弹、连发节奏），
##   本文件管"一发子弹打出去之后发生什么" —— 纯函数，不持有状态。
##   这样两侧都能独立演进：加新命中反馈不用碰换弹逻辑，反之亦然。
## 设计: 全部 static 且显式传参（不读 weapon 的成员），便于单元测试与复用。
extends RefCounted

## 在 basis 的 -Z 轴上加随机锥形散布。spread_degrees = 0 时零开销直射。
static func apply_spread(basis: Basis, spread_degrees: float) -> Vector3:
	var forward: Vector3 = -basis.z
	if spread_degrees <= 0.0:
		return forward.normalized()
	var rad: float = deg_to_rad(spread_degrees)
	# 均匀圆盘采样：sqrt 保证面积均匀，避免中心过密
	var r: float = sqrt(randf()) * rad
	var theta: float = randf() * TAU
	var offset: Vector3 = basis.x * (cos(theta) * r) + basis.y * (sin(theta) * r)
	return (forward + offset).normalized()

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

	var collider: Object = hit.get("collider") as Object
	var point: Vector3 = hit.get("position", to) as Vector3
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	var weakspot: bool = is_weakspot(collider)
	var target: Node = resolve_damage_target(collider)
	if target != null:
		var dmg: float = data.effective_damage()
		if weakspot:
			dmg *= data.weakspot_multiplier
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
