## 战斗输入分派层：把「按了什么键 → 对武器/开镜/推挤做什么」从 Player 里切出来。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 拆出理由（PDF 硬红线：单文件 ≤ 300 行）：
##   player.gd 接入 aim / bash 后到 328 行。战斗输入这一段与移动、视角、
##   血量、回复四块零耦合 —— 它只碰 Arsenal 与两个策略对象，天然可搬走。
## 参数为什么是四个裸对象而不是 Player：
##   本层被 player.gd 以 const preload 引用，若签名里出现 Player 类型，
##   Player ↔ 本文件形成 Cyclic reference，Godot 解析期直接报错。
##   所以这里只收 Node3D + RefCounted，靠 duck typing 调用，零类型耦合。
## 输入语义（物理键 ↔ 语义动作的映射在 InputSetup.apply_scheme）：
##   fire  = 左键（两套方案相同）
##   aim   = 中键（L4D 方案）/ 右键（经典方案）
##   bash  = 右键（L4D 方案）/ V 键（经典方案）
##   **本层永远不判断"现在哪套方案"** —— 那是 InputMap 的事。
extends RefCounted

## 处理一次战斗输入。返回是否消费了该事件（未命中任何动作返回 false）。
static func handle(event: InputEvent, player: Node3D, arsenal: RefCounted,
		aim: RefCounted, shove: RefCounted) -> bool:
	var weapon: Weapon = arsenal.current() as Weapon

	if event.is_action_pressed(&"fire"):
		if weapon != null:
			weapon.pull_trigger()
		return true
	if event.is_action_released(&"fire"):
		if weapon != null:
			weapon.release_trigger()
		return true
	if event.is_action_pressed(&"reload"):
		if weapon != null:
			weapon.start_reload()
		return true
	if event.is_action_pressed(&"aim"):
		# 返回 true 表示真的切换了状态：重复按下不重发 ads_changed
		if aim.set_aiming(true, player.get_tree()):
			_sync_ads(weapon, aim)
		return true
	if event.is_action_released(&"aim"):
		if aim.set_aiming(false, player.get_tree()):
			_sync_ads(weapon, aim)
		return true
	if event.is_action_pressed(&"bash"):
		# 冷却在 Shove 内部，这里不做门控 —— 空推也要进冷却才符合 L4D 手感
		if shove.ready_to_shove():
			shove.perform(player)
		return true

	if event.is_action_pressed(&"weapon_1"):
		arsenal.equip(0)
		return true
	if event.is_action_pressed(&"weapon_2"):
		arsenal.equip(1)
		return true
	if event.is_action_pressed(&"weapon_3"):
		arsenal.equip(2)
		return true
	if event.is_action_pressed(&"weapon_next"):
		arsenal.cycle(1)
		return true
	if event.is_action_pressed(&"weapon_prev"):
		arsenal.cycle(-1)
		return true
	return false

## 把当前开镜乘数灌给武器。切枪后必须重灌 —— 新枪的 _ads_* 还是默认 1.0。
static func _sync_ads(weapon: Weapon, aim: RefCounted) -> void:
	if weapon == null:
		return
	weapon.set_ads(aim.aiming, aim.spread_scale(), aim.recoil_scale())

## 切枪后重新同步开镜状态（由 Player._equip 调用）。
## 存在理由：开镜中切枪，新武器不知道玩家正在开镜，散布会突然变大。
static func resync_ads(arsenal: RefCounted, aim: RefCounted) -> void:
	_sync_ads(arsenal.current() as Weapon, aim)
