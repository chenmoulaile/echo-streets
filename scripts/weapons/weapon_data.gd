## 武器静态数据（Resource，可在 Inspector 里新建 .tres 给每把枪配一份）
## class_name: WeaponData
## 挂载节点类型: 不是节点 —— extends Resource。由 Weapon 节点通过 @export 引用。
## 依赖信号: 无
## 节点路径假设: 无
## 与 PDF 的对应: "武器分三层——现实军械（手枪/霰弹枪/冲锋枪/步枪/狙击枪/爆破物
##                各一把）+ 科研特制 + BA 道具"；"弹匣容量与备弹量构成资源管理，
##                换弹时机是核心博弈点"。本资源即三层武器的统一数据契约。
## 强化词条红线（PDF）：单条增益 ≤10% 量级。fire_rate_multiplier /
##                reload_time_multiplier 等字段刻意用乘数而非百分比整数，
##                便于词条系统叠加且不越红线。
class_name WeaponData
extends Resource

enum FireMode {
	SEMI_AUTO,   ## 单发：每按一次扳机打一发
	FULL_AUTO,   ## 全自动：按住连发
	BURST,       ## 点射：一次扳机打 burst_count 发
}

enum WeaponClass {
	KINETIC,     ## 现实军械
	RESEARCH,    ## 科研特制
	BA_ITEM,     ## BA 道具
}

@export_group("标识")
@export var display_name: String = "手枪"
@export var weapon_class: WeaponClass = WeaponClass.KINETIC
## HUD 图标（PDF: 枪械 HUD 约 160×120，Nearest 过滤）
@export var hud_texture: Texture2D
## HUD viewmodel 是否用霰弹枪帧组（assets/sprites/viewmodel/vm_shotgun_*）。
## 不用 display_name 或贴图名判断：改名就断，这个字段是显式契约。
@export var shotgun_viewmodel: bool = false

@export_group("射击")
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
## 每分钟发射次数。射速 = 60 / rounds_per_minute 秒/发。
@export var rounds_per_minute: float = 300.0
## 单发弹丸数。霰弹枪 8~10，其余 1。
@export var pellets: int = 1
## 散布半角（度）。0 = 绝对精准（狙击枪开镜）。
@export var spread_degrees: float = 1.0
## 单发伤害（每颗弹丸独立结算）
@export var damage: float = 20.0
## 弱点倍率（命中 WEAKSPOT 层时乘算）
@export var weakspot_multiplier: float = 2.0
## 最大射程（米）。超出的射线不结算伤害。
@export var max_range: float = 100.0
## 后坐力强度（度），玩家控制器拿来做镜头抬枪
@export var recoil: float = 1.0
## 点射发数（仅 BURST 模式生效）
@export var burst_count: int = 3

@export_group("弹药经济")
## 弹匣容量
@export var magazine_size: int = 12
## 初始备弹
@export var reserve_ammo: int = 60
## 备弹上限（拾取时不可超过）
@export var max_reserve_ammo: int = 180
## 换弹时长（秒）
@export var reload_time: float = 1.5
## 是否逐发装填（霰弹枪/狙击枪：可中途打断，打几发装几发）
@export var reload_per_shell: bool = false

@export_group("词条乘数")
## 射速乘数（1.08 = 扳机调校 +8%）
@export var fire_rate_multiplier: float = 1.0
## 换弹时长乘数（0.88 = 战术装填 -12%）
@export var reload_time_multiplier: float = 1.0
## 伤害乘数
@export var damage_multiplier: float = 1.0

# ── 派生量（带词条乘数，调用方一律用这些而不是裸字段）──────────────

## 两发之间的间隔秒数
func shot_interval() -> float:
	var rpm: float = maxf(rounds_per_minute * fire_rate_multiplier, 1.0)
	return 60.0 / rpm

## 实际换弹时长（秒）
func effective_reload_time() -> float:
	return maxf(reload_time * reload_time_multiplier, 0.05)

## 实际单发伤害
func effective_damage() -> float:
	return damage * damage_multiplier

## 校验配置合法性，返回问题列表（空数组 = 合法）。供 @tool 编辑器检查用。
func validate() -> PackedStringArray:
	var issues: PackedStringArray = []
	if magazine_size <= 0:
		issues.append("magazine_size 必须 > 0")
	if pellets <= 0:
		issues.append("pellets 必须 > 0")
	if rounds_per_minute <= 0.0:
		issues.append("rounds_per_minute 必须 > 0")
	if reload_time <= 0.0:
		issues.append("reload_time 必须 > 0")
	if max_range <= 0.0:
		issues.append("max_range 必须 > 0")
	if burst_count <= 0 and fire_mode == FireMode.BURST:
		issues.append("BURST 模式下 burst_count 必须 > 0")
	return issues
