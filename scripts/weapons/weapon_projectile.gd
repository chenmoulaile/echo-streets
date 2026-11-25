## 飞行中的弹丸（真实初速弹道）
## class_name: WeaponProjectile
## 挂载节点类型: 不是节点 —— extends RefCounted，由 Weapon 持有数组。
## 依赖信号: 无（命中结算仍走 weapon_ballistics.gd 的 resolve_hit）
## 为什么需要它（用户 m09845：「枪械的伤害以及子弹初速是否真实」）：
##   原来 weapon_ballistics.fire_pellet 一发只投一条 max_range 长的射线，
##   命中在开火那一帧就结算 —— 子弹没有飞行时间，90 米外和贴脸同时掉血。
##   本类把「一条射线」拆成「按初速逐帧推进的线段」，命中延迟 = 距离 / 初速。
## 为什么每帧只投一条线段就够了（不是分段小步）：
##   intersect_ray 是线段查询（从 from 到 to 整段求交），不是点查询，
##   所以哪怕一帧走 6.3 米（380m/s @ 60fps）也不会穿过薄墙 —— 段内任何
##   交点都会被返回。真正的隧穿只会发生在「瞬移但不投射」，这里不存在。
## 为什么速度取 0 时退回 hitscan（weapon.gd 判定）：
##   15 米内 380m/s 的飞行时间只有 39 毫秒（2~3 帧），玩家感知不到，
##   而霰弹枪 8 颗弹丸每帧一条射线 × 约 15 帧 = 120 次射线，纯浪费。
##   所以初速是「想真实就填，不想就留 0」的开关，不是硬性改动。
class_name WeaponProjectile
extends RefCounted

const Ballistics := preload("res://scripts/weapons/weapon_ballistics.gd")

## 出膛点（摄像机中心，与 hitscan 同一语义）
var origin: Vector3 = Vector3.ZERO
## 已归一化的飞行方向（散布在开火瞬间采样一次，飞行途中不再抖）
var direction: Vector3 = Vector3.FORWARD
## 初速（米/秒），来自 WeaponData.muzzle_velocity
var speed: float = 400.0
## 射程上限（米），来自 WeaponData.max_range
var max_range: float = 100.0
## 命中结算用：伤害与弱点倍率在开火瞬间快照，飞行途中改词条不影响在飞的弹
var damage: float = 20.0
var weakspot_multiplier: float = 2.0
## 已飞距离
var travelled: float = 0.0
## 射线排除体（射手自己的 RID），必须拷贝一份 —— 不能共享数组引用
var exclude: Array[RID] = []
var shooter: Node3D

var _done: bool = false

static func spawn(data: WeaponData, from: Vector3, dir: Vector3, shooter_node: Node3D,
		exclude_rids: Array[RID], spread_scale: float = 1.0) -> WeaponProjectile:
	var p := WeaponProjectile.new()
	p.origin = from
	p.direction = Ballistics.apply_spread_from(dir, data.spread_degrees * maxf(spread_scale, 0.0))
	p.speed = maxf(data.muzzle_velocity, 1.0)
	p.max_range = data.max_range
	p.damage = data.effective_damage()
	p.weakspot_multiplier = data.weakspot_multiplier
	p.exclude = exclude_rids.duplicate()
	p.shooter = shooter_node
	return p

## 推进一帧。返回 true 表示这颗粒已终结（命中或飞满射程），调用方可以移除。
func advance(world: World3D, delta: float) -> bool:
	if _done:
		return true
	var left: float = max_range - travelled
	if left <= 0.0:
		_done = true
		return true
	var step: float = minf(speed * delta, left)
	if step <= 0.0:
		return false
	var from: Vector3 = origin + direction * travelled
	var to: Vector3 = from + direction * step
	var query := PhysicsRayQueryParameters3D.create(
		from, to, GameLayers.MASK_HITSCAN, exclude
	)
	query.collide_with_areas = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		Ballistics.resolve_hit(hit, damage, weakspot_multiplier, shooter)
		_done = true
		return true
	travelled += step
	if travelled >= max_range - 0.0001:
		_done = true
	return _done
