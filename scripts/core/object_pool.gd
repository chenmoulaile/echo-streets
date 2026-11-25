## 通用对象池（丧尸 / 抛射物 / 特效共用）
## class_name: ObjectPool
## 挂载节点类型: Node（由 WaveSpawner 或 GameManager 在代码里创建并 add_child）
## 依赖信号: 无（纯同步 API，不走 EventBus）
## 节点路径假设: 无。池节点自身即父容器，池内实例都是它的子节点。
## 与 PDF 的对应: "丧尸、子弹与特效全部对象池化复用，目标同屏 60 只丧尸稳定 60 帧"。
## 池化节点可选实现两个回调（由本池自动调用）:
##   _on_pool_acquired()  —— 出池，做状态复位（血量回满、清目标、重置动画）
##   _on_pool_released()  —— 回池，做清理（停音效、关粒子）
## 重要: 池化节点永远不 queue_free，只切 process_mode + visible。
class_name ObjectPool
extends Node

## 池化实例可实现的回收方法名。节点内部想主动归还时调 pool.release(self)。
const RELEASE_METHOD := &"release_to_pool"

@export var scene: PackedScene          ## 被池化的场景（必须在 add_child 前赋值）
@export var initial_size: int = 20      ## 预分配数量（Phase 1 压力测试按 60 调）
@export var max_size: int = 128         ## 硬上限，超出时 acquire 返回 null 并告警
@export var auto_expand: bool = true    ## 池耗尽时是否允许扩容到 max_size

var _idle: Array[Node] = []             ## 空闲节点
var _active: Array[Node] = []           ## 使用中节点

func _ready() -> void:
	add_to_group(GameLayers.GROUP_POOL)
	_prewarm(initial_size)

# ── 取 / 还 ─────────────────────────────────────────────────────

## 取一个实例。池满且不允许扩容时返回 null（调用方必须判空）。
func acquire() -> Node:
	var node: Node = null
	if _idle.is_empty():
		if auto_expand and _idle.size() + _active.size() < max_size:
			node = _create_instance()
		else:
			push_warning("ObjectPool[%s]: 池已耗尽（max_size=%d）。" % [name, max_size])
			return null
	else:
		node = _idle.pop_back()
	if node == null:
		return null
	_active.append(node)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	_set_visible(node, true)
	if node.has_method(&"_on_pool_acquired"):
		node.call(&"_on_pool_acquired")
	return node

## 归还实例。重复归还同一节点是安全的（静默忽略）。
## 也接受"本池的子节点但不在 _active 里"的实例（例如被外部 reparent 进来、
## 或从子场景手动挂载的节点）——否则它会以死亡状态永久留在树里。
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var owned: bool = _active.has(node)
	if not owned:
		# 只收养自己的直接子节点，避免把别人的节点拖进池
		if node.get_parent() != self or _idle.has(node):
			return
	_active.erase(node)
	if node.has_method(&"_on_pool_released"):
		node.call(&"_on_pool_released")
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_set_visible(node, false)
	_idle.append(node)

## 全部回收（关卡结束 / 玩家死亡清场用）
func release_all() -> void:
	for node: Node in _active.duplicate():
		release(node)

# ── 查询 ────────────────────────────────────────────────────────

## 当前活跃数量（Director 压力计算用）
func active_count() -> int:
	return _active.size()

## 池当前总容量（空闲 + 活跃）
func capacity() -> int:
	return _idle.size() + _active.size()

## 是否有空闲实例可用（避免 acquire 触发扩容抖动）
func has_idle() -> bool:
	return not _idle.is_empty()

## 三级兜底定位"该节点属于哪个池"，供池化节点在自己的 _ready / 归还时调用：
##   ① 调用方给的 hint 路径（Inspector 直连，最可靠）
##   ② 沿父链上溯，第一个 ObjectPool 祖先（运行时自建池走这条）
##   ③ 场景里任意一个已入组的 ObjectPool（单池项目的最终兜底）
## 旧骨架硬编码 get_first_node_in_group("ZombiePool") 且池从未入组 → 必然失效。
static func resolve_for(node: Node, hint: NodePath = NodePath()) -> ObjectPool:
	if node == null or not node.is_inside_tree():
		return null
	if not hint.is_empty():
		var direct: ObjectPool = node.get_node_or_null(hint) as ObjectPool
		if direct != null:
			return direct
	var cursor: Node = node.get_parent()
	while cursor != null:
		if cursor is ObjectPool:
			return cursor as ObjectPool
		cursor = cursor.get_parent()
	return node.get_tree().get_first_node_in_group(GameLayers.GROUP_POOL) as ObjectPool

# ── 内部 ────────────────────────────────────────────────────────

func _prewarm(count: int) -> void:
	for _i: int in count:
		var node: Node = _create_instance()
		if node == null:
			break
		_idle.append(node)

func _create_instance() -> Node:
	if scene == null:
		push_error("ObjectPool[%s]: scene 未设置，无法实例化。" % name)
		return null
	var node: Node = scene.instantiate()
	# 先入树再置休眠：让 _ready 正常跑一次（信号连接、@onready 引用都在此时建立）
	add_child(node)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_set_visible(node, false)
	if node.has_method(&"_on_pool_released"):
		node.call(&"_on_pool_released")
	return node

## Node3D 用 visible，2D/其它用 process 控制即可，避免类型判断散落各处
func _set_visible(node: Node, value: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = value
	elif node is CanvasItem:
		(node as CanvasItem).visible = value
