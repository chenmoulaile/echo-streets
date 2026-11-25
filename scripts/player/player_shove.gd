## 推挤（shove）结算层：前方扇形内的丧尸推开 + 硬直，零伤害。
## 挂载节点类型: 无（extends RefCounted，由 Player 持有实例）
## 拆出理由（PDF 硬红线：单文件 ≤ 300 行）：
##   player.gd 294 行已贴顶，推挤的判定链（存活/距离/角度/视线）约 55 行，
##   塞进去必然越线。且推挤是纯判定 + 派发，不读玩家任何成员，天然可独立。
## 参考 Left 4 Dead：右键推挤是"保命而非输出"——推开的丧尸不掉血，
##   只被强行打断一次攻击并获得硬直。所以本层不调 take_damage。
## 判定顺序（顺序本身是性能与语义设计，不要调整）：
##   1. 存活     —— 池中休眠与已死亡的实例先踢掉，省掉后续全部计算
##   2. 距离     —— 半径外直接跳过，这是绝大多数目标被淘汰的一步
##   3. 角度     —— 只打正前方扇形，背后偷袭的丧尸推不到（玩家必须转身）
##   4. 视线     —— 隔着墙/门推不动，复用 ZombieSteering.has_line_of_sight
## 每次推挤最多命中 SHOVE_MAX_TARGETS 只，避免一推清场。
extends RefCounted

## 推挤有效半径（米）。略大于 attack_range 1.6，玩家能在被抓到前抢先推开。
const SHOVE_RANGE := 2.2
## 扇形半角（度）。50° 半角 = 100° 正面锥，转身 90° 就推不到侧后目标。
const SHOVE_HALF_ANGLE := 50.0
## 击退初速度（米/秒）。配合 ZombieBase.SHOVE_TIME 0.18s ≈ 后退 1.26m。
const SHOVE_SPEED := 7.0
## 硬直时长（秒）。够玩家拉一次栓或后退两步，不足以无限连推。
const SHOVE_STAGGER := 0.55
## 冷却（秒）。按住不放也只会每 0.9 秒推一次。
const SHOVE_COOLDOWN := 0.9
## 单次推挤最多命中数量。防止被 20 只围住时一推全清。
const SHOVE_MAX_TARGETS := 5

var _cooldown: float = 0.0

## 冷却推进。由 Player._physics_process 每帧调用。
func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)

func ready_to_shove() -> bool:
	return _cooldown <= 0.0

func reset() -> void:
	_cooldown = 0.0

## 执行一次推挤。返回实际命中的丧尸数量（0 表示空推，也要进冷却）。
## player 必须已 add_to_group(GameLayers.GROUP_PLAYER) 且朝向由 -Z 表达。
func perform(player: Node3D) -> int:
	if player == null:
		return 0
	_cooldown = SHOVE_COOLDOWN
	var tree: SceneTree = player.get_tree()
	if tree == null:
		return 0
	var origin: Vector3 = player.global_position
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0
	forward = forward.normalized()

	var cos_limit: float = cos(deg_to_rad(SHOVE_HALF_ANGLE))
	var world: World3D = player.get_world_3d()
	var self_rid: RID = (player as CollisionObject3D).get_rid() \
		if player is CollisionObject3D else RID()
	var eye: Vector3 = origin + Vector3(0.0, 1.0, 0.0)
	var hits: int = 0

	for node: Node in tree.get_nodes_in_group(GameLayers.GROUP_ZOMBIE):
		if hits >= SHOVE_MAX_TARGETS:
			break
		var zombie: ZombieBase = node as ZombieBase
		if zombie == null or not zombie.is_active_zombie():
			continue
		var offset: Vector3 = zombie.global_position - origin
		offset.y = 0.0
		var dist: float = offset.length()
		if dist <= 0.0001 or dist > SHOVE_RANGE:
			continue
		if forward.dot(offset / dist) < cos_limit:
			continue
		if world != null and not ZombieSteering.has_line_of_sight(
				world, self_rid, eye, zombie.global_position + Vector3(0.0, 1.0, 0.0),
				zombie, GameLayers.MASK_HITSCAN):
			continue
		zombie.apply_shove(origin, SHOVE_SPEED, SHOVE_STAGGER)
		EventBus.zombie_shoved.emit(zombie)
		hits += 1

	EventBus.player_shoved.emit(hits)
	return hits
