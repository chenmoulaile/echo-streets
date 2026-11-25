## 玩家武器槽管理层：收集 / 切换 / 循环 / 当前武器。
## 挂载节点类型: 无（extends RefCounted，由 Player 持有实例）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   player.gd 在补齐视角/后坐/血量/回复四处解耦后仍有 323 行，超红线。
##   武器槽是本章耦合度最低的一块：它只碰 Weapon 节点与 EventBus，
##   与移动、视角、血量完全无关，且自带两条实测注释（切枪补发弹药、HUD 拉取）。
## 与 PDF 的对应:
##   "换弹时机是核心博弈点" → 切枪打断换弹（cancel_reload(SWITCH)）是这里的规则。
extends RefCounted

var weapons: Array[Weapon] = []
var index: int = 0

## 收集 WeaponMount 下所有 Weapon 子节点。
## 返回是否收集到至少一把（false 时调用方应 push_warning）。
func collect(mount: Node3D) -> bool:
	weapons.clear()
	if mount == null:
		return false
	for child: Node in mount.get_children():
		var w: Weapon = child as Weapon
		if w != null:
			weapons.append(w)
	return not weapons.is_empty()

## 当前手持武器。下标越界时返回 null（而非崩溃）。
func current() -> Weapon:
	if index < 0 or index >= weapons.size():
		return null
	return weapons[index]

## 切到指定槽位。force=true 时即使下标相同也重发事件
## （_ready 里首帧装备必须 force，否则 HUD 收不到初始武器）。
func equip(slot: int, force: bool = false) -> void:
	if weapons.is_empty():
		return
	var clamped: int = clampi(slot, 0, weapons.size() - 1)
	if clamped == index and not force:
		return
	var prev: Weapon = current()
	if prev != null:
		prev.cancel_reload(Weapon.ReloadCancelReason.SWITCH)
		prev.release_trigger()
		prev.visible = false
		prev.set_process(false)
	index = clamped
	var cur: Weapon = weapons[index]
	cur.visible = true
	cur.set_process(true)
	if cur.data != null:
		EventBus.weapon_switched.emit(cur.data, index)
	# 切枪必须补发弹药：两个 Weapon 的 _ready 都会 call_deferred 广播一次，
	# 后完成的那把会覆盖 HUD 显示，导致槽位 0 显示成霰弹枪的 6/24。
	EventBus.ammo_changed.emit(cur.mag_ammo(), cur.reserve_ammo())

## 循环切换。只有一把枪时不动。
func cycle(step: int) -> void:
	if weapons.size() <= 1:
		return
	equip(posmod(index + step, weapons.size()))

## 全部武器恢复初始弹药（关卡重置 / 复活）
func reset_all() -> void:
	for w: Weapon in weapons:
		w.reset_ammo()
