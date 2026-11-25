## 单波次配置（Resource，可在 Inspector 里新建 .tres 编排出整关节奏）
## class_name: WaveConfig
## 挂载节点类型: 不是节点 —— extends Resource，由 WaveSpawner 通过 Array[WaveConfig] 引用
## 依赖信号: 无
## 节点路径假设: 无
## 为什么独立成文件而不是 WaveSpawner 的内部 class:
##   内部 class 没有 class_name，跨文件写 `Array[WaveConfig]` 时类型无法解析，
##   Inspector 也不能把 .tres 拖进导出数组。独立文件两个问题一起解决。
## 与 PDF 的对应: "导演系统输出刷怪间隔与特感投放权重"——本资源是导演输出侧的
##                数据落点；"杂鱼丧尸高密度 + 冲锋者/自爆者/尖啸者/拖曳者"由
##                entries 里的权重表表达。
class_name WaveConfig
extends Resource

@export_group("波次规模")
## 本波丧尸总数
@export var total_count: int = 12
## 同屏存活上限（PDF 压力测试目标：60）
@export var max_alive: int = 24
## 刷怪间隔（秒）。0 = 一次性全部放出（仅调试用）。
@export var spawn_interval: float = 0.8
## 本波开始前的准备时间（秒），给玩家换弹/走位
@export var prepare_time: float = 3.0
## 清空本波后到下一波的间隔（秒）
@export var rest_time: float = 4.0

@export_group("敌人配比")
## 杂鱼丧尸场景（必填）。其余特感通过 special_scenes 追加。
@export var fodder_scene: PackedScene
## 特感场景列表，与 special_weights 一一对应
@export var special_scenes: Array[PackedScene] = []
## 特感投放权重。权重越高越早/越频繁出现。
@export var special_weights: Array[float] = []
## 特感占总数的比例（0.0~1.0）。0 = 纯杂鱼。
@export var special_ratio: float = 0.0

@export_group("难度曲线")
## 本波丧尸移速乘数（相对 Zombie.move_speed）
@export var speed_multiplier: float = 1.0
## 本波丧尸血量乘数
@export var health_multiplier: float = 1.0

## 校验配置，返回问题列表（空 = 合法）
func validate() -> PackedStringArray:
	var issues: PackedStringArray = []
	if fodder_scene == null:
		issues.append("fodder_scene 未设置")
	if total_count <= 0:
		issues.append("total_count 必须 > 0")
	if max_alive <= 0:
		issues.append("max_alive 必须 > 0")
	if special_scenes.size() != special_weights.size():
		issues.append("special_scenes 与 special_weights 长度必须一致")
	for s: PackedScene in special_scenes:
		if s == null:
			issues.append("special_scenes 含 null 元素")
			break
	return issues

## 按权重抽一个特感场景。无特感配置时返回 null。
func pick_special() -> PackedScene:
	if special_scenes.is_empty():
		return null
	var total: float = 0.0
	for w: float in special_weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return special_scenes[0]
	var roll: float = randf() * total
	var acc: float = 0.0
	for i: int in special_scenes.size():
		acc += maxf(special_weights[i], 0.0)
		if roll <= acc:
			return special_scenes[i]
	return special_scenes[special_scenes.size() - 1]
