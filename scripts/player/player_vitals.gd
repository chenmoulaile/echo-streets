## 玩家血量与击杀回复策略层。
## 挂载节点类型: 无（extends RefCounted，全部 static 或纯函数）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   player.gd 在补齐受击无敌帧、击杀回复预算、死亡清理后涨到 316 行，超红线。
##   职责切分：player.gd 管"运动与武器"（移动/视角/切枪），
##   本文件管"生命值结算规则" —— 伤害折扣、击杀回复预算、死亡时的武器清理。
##   两者唯一的耦合是 HealthComponent 与 EventBus，都通过参数显式传入。
## 与 PDF 的对应:
##   "战地医疗包：击杀回 2 血，每秒上限 20" —— 这个每秒上限就是 kill_heal 预算，
##   必须有状态（本秒已用多少），所以放在一个可实例化的类里而不是纯 static 函数。
extends RefCounted

## 每秒击杀回复上限（PDF 词条硬约束）
var heal_per_second_cap: float = 20.0
## 每次击杀回复量
var heal_amount: float = 0.0

var _budget: float = 0.0  ## 本秒剩余可回复量

## 每帧回充预算（上限封顶，不累积到下一帧）
func tick(delta: float) -> void:
	_budget = minf(_budget + heal_per_second_cap * delta, heal_per_second_cap)

## 结算一次击杀回复。返回实际回复量（可能被预算截断）。
## heal_fn 由调用方给（player 传自己的 heal），避免本层依赖节点。
func on_kill(heal_fn: Callable) -> float:
	if heal_amount <= 0.0:
		return 0.0
	var want: float = minf(heal_amount, _budget)
	if want <= 0.0:
		return 0.0
	var gained: float = float(heal_fn.call(want))
	_budget -= gained
	return gained

## 重置（复活 / 关卡重开）
func reset() -> void:
	_budget = 0.0

## 死亡时的统一清理：打断换弹、松开扳机、交还鼠标。
## 抽成 static 是因为它只依赖传入的 weapon 与 Input 单例，
## 不读任何本类状态 —— 放在这里让 player 的 _on_died 只剩三行。
static func handle_death(weapon: Weapon) -> void:
	if weapon != null:
		weapon.cancel_reload(Weapon.ReloadCancelReason.DEATH)
		weapon.release_trigger()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
