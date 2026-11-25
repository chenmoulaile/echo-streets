## 通用血量组件（玩家 / 丧尸 / BOSS 共用）
## class_name: HealthComponent
## 挂载节点类型: Node（作为 CharacterBody3D / 敌人根节点的子节点）
## 依赖信号: 向外发 health_changed / died；由宿主脚本 connect 到 EventBus
## 节点路径假设: 父节点需有 take_damage() 转发到本组件（或宿主直接调 apply_damage）
## 与 PDF 的对应: 强化词条"战地医疗包：击杀回复 2 点生命（每秒上限 20）"
##                → 由 HOST 侧做每秒上限限流，本组件只保证 heal 不溢出 max_health。
## 设计要点:
##   1. 不依赖 owner —— 池化实例的 owner 为 null，旧实现用 owner 做判空会让池化丧尸
##      永远收不到受击事件。本实现零 owner 依赖。
##   2. 血量用 float 存，HUD 与伤害数字走 float，避免整数取整导致的"打不死"。
##   3. 死亡只发一次信号（_is_dead 幂等守卫），防止同帧多次命中重复触发击杀计数。
class_name HealthComponent
extends Node

## 血量变化（当前, 最大）。HUD 与血条直连。
signal health_changed(current: float, max_value: float)
## 受击（实际扣血量, 是否致命, 攻击者节点）。攻击者可为 null（环境伤害）。
signal damaged(amount: float, is_fatal: bool, source: Node)
## 治疗（实际回复量）
signal healed(amount: float)
## 死亡，仅触发一次
signal died(source: Node)

@export var max_health: float = 100.0
## 无敌帧：受击后该秒数内免疫后续伤害。0 = 无无敌帧。
@export var invulnerable_time: float = 0.0
## 弱点倍率（命中 WEAKSPOT 层时由武器侧乘好再传入，这里仅存一份便于集中配置）
@export var weakspot_multiplier: float = 2.0

var _current: float = 0.0
var _is_dead: bool = false
var _invuln_left: float = 0.0

func _ready() -> void:
	_current = max_health
	# 延迟一帧广播，确保监听方（HUD）已完成 connect
	_broadcast.call_deferred()

func _process(delta: float) -> void:
	if _invuln_left > 0.0:
		_invuln_left = maxf(_invuln_left - delta, 0.0)

# ── 查询 ────────────────────────────────────────────────────────

func is_alive() -> bool:
	return not _is_dead

func is_full() -> bool:
	return _current >= max_health

func current_health() -> float:
	return _current

func health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return _current / max_health

# ── 变更 ────────────────────────────────────────────────────────

## 扣血。返回实际扣掉的量（被无敌帧 / 已死亡时返回 0）。
func apply_damage(amount: float, source: Node = null) -> float:
	if _is_dead or amount <= 0.0 or _invuln_left > 0.0:
		return 0.0
	var before: float = _current
	_current = maxf(_current - amount, 0.0)
	var dealt: float = before - _current
	if _invuln_left <= 0.0 and invulnerable_time > 0.0:
		_invuln_left = invulnerable_time
	var fatal: bool = _current <= 0.0
	health_changed.emit(_current, max_health)
	damaged.emit(dealt, fatal, source)
	if fatal:
		_die(source)
	return dealt

## 治疗。返回实际回复量（已死亡 / 满血时返回 0）。
func heal(amount: float) -> float:
	if _is_dead or amount <= 0.0 or _current >= max_health:
		return 0.0
	var before: float = _current
	_current = minf(_current + amount, max_health)
	var gained: float = _current - before
	health_changed.emit(_current, max_health)
	healed.emit(gained)
	return gained

## 池化复用：回满并清死亡标记。由 ObjectPool 的 _on_pool_acquired 调用。
func reset_health() -> void:
	_is_dead = false
	_invuln_left = 0.0
	_current = max_health
	health_changed.emit(_current, max_health)

## 直接击杀（坠落、脚本清场用），仍会正常广播 died。
func kill(source: Node = null) -> void:
	if _is_dead:
		return
	_current = 0.0
	health_changed.emit(_current, max_health)
	_die(source)

# ── 内部 ────────────────────────────────────────────────────────

func _die(source: Node) -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit(source)

func _broadcast() -> void:
	if is_inside_tree():
		health_changed.emit(_current, max_health)
