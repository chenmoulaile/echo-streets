## 章节数据容器：一章 = 一套几何原语 + 光源 + 刷怪点 + 波次 + 后处理参数。
## class_name: ChapterData
## 挂载节点类型: 无（纯数据，extends RefCounted）
## 存在理由: 4 个章节若各写一份 BuildWorld 逻辑，改一处光照就要改四遍。
##   这里把"一章长什么样"收敛成数据，ChapterBuilder 只负责翻译一次。
## 为什么不是 Resource: 章节定义是代码（用循环铺灯、按索引算坐标），
##   写成 .tres 反而要手抄几十个 Vector3；RefCounted 直接 new 出来即可，
##   也避免 .tres 序列化在 headless 构建期多一次资源依赖解析。
class_name ChapterData
extends RefCounted

## 章节标识（存档里记录用，改了就断存档，只在真的换章时才改）
var id: String = "chapter_00"
## 章节标题（HUD 开场横幅 / 关卡完成提示）
var title: String = "UNTITLED"
## 副标题（一行气氛描述，显示在标题下方）
var subtitle: String = ""
## 目标文案（HUD 左上常驻）
var objective: String = "CLEAR THE STREET"

## 玩家出生点（脚底位置）与朝向（度）
var player_start: Vector3 = Vector3(0.0, 0.0, 14.0)
var player_yaw: float = 0.0

## 几何原语（ChapterKit.box / panel / curtain 的产物）
var geometry: Array = []
## 构建期光源（ChapterKit.lamp 的产物）。运行时不生成任何灯节点。
var lamps: Array = []
## 刷怪点（Vector3 数组）
var spawn_points: Array = []

## 波次参数表。每项是 Dictionary：
##   {total, max_alive, interval, prepare, rest, special_ratio, speed, health}
var waves: Array = []

## 半球环境光（覆盖 LightBaker 默认值，用来区分"冷白大堂"与"暖黄商场"）
var ambient_sky: Color = Color(0.62, 0.64, 0.68)
var ambient_ground: Color = Color(0.34, 0.33, 0.32)

## 后处理覆盖参数（键名必须与 pixelzombie_postprocess.gdshader 的 uniform 一致）
var post: Dictionary = {}

## 全景天空贴图（等距柱状 2:1）。空串 = 不用天空，用纯色背景（室内章）。
## 为什么必须是 2:1：PanoramaSkyMaterial 按等距柱状投影采样，v=0.5 是地平线。
##   assets/materials/SkyTexture_Sunset.png 是 3860x960（4:1）且地平线在 50%，
##   直接喂会得到上下颠倒的色块 —— 已由 tmp/BuildSky.gd 转成标准 2:1 版本。
var sky_texture: String = ""
## 天空绕 Y 轴旋转（度）。同一张天空图靠旋转可以让四章看到不同的落日方位。
var sky_rotation_deg: float = 0.0
## 天空亮度。天空同时作为环境光来源，太高会把烘焙好的明暗关系压平。
var sky_energy: float = 0.9
## 太阳方向光强度（0 = 无太阳，室内章必须为 0）。
## 为什么需要这一项：本项目所有材质是 SHADING_MODE_UNSHADED，真 DirectionalLight3D
##   对它们毫无作用，落日只是 skybox 里一张装饰图 —— 审核实测 ch04 左右两区
##   mean 逐位相同 0.532/0.532，完全看不出太阳在哪边。
## 只在露天章开启（ch04 = 0.55）。室内章开这个会把地板照成户外日照，
##   与"室内吊顶灯"的明暗关系冲突。
var sun_gain: float = 0.0
## 垂直面环境光增益（覆盖 LightBaker 的默认 1.55）。
## 室内章靠它补偿"对面墙互反射"，露天章必须设 0 —— 露天没有对面墙，
## 而 1.55 会把垂直面环境项顶到饱和，把太阳直射项完全吃掉（实测差 0.000）。
## 空值（-1）表示沿用 LightBaker 默认值。
var horizon_gain: float = -1.0

## 建造参数：网格边长（米）。1.0 时光池边缘平滑，2.0 时顶点数减半但块感明显。
var mesh_step: float = 1.0

## 便捷构造：链式设置，章节文件读起来像配置表而不是一堆赋值语句。
static func make(p_id: String, p_title: String, p_subtitle: String) -> ChapterData:
	var d := ChapterData.new()
	d.id = p_id
	d.title = p_title
	d.subtitle = p_subtitle
	return d

func with_player(pos: Vector3, yaw_deg: float = 0.0) -> ChapterData:
	player_start = pos
	player_yaw = yaw_deg
	return self

func with_ambient(sky: Color, ground: Color) -> ChapterData:
	ambient_sky = sky
	ambient_ground = ground
	return self

func with_post(overrides: Dictionary) -> ChapterData:
	post = overrides
	return self

## 设置全景天空。tex_path 必须是 2:1 等距柱状图。
## sun 是太阳方向光强度：露天章传 0.4~0.6，室内章保持默认 0。
## 开启太阳时自动把 horizon_gain 归零（露天无对面墙，否则太阳被环境项吃掉）。
func with_sky(tex_path: String, rotation_deg: float = 0.0, energy: float = 0.9,
		sun: float = 0.0) -> ChapterData:
	sky_texture = tex_path
	sky_rotation_deg = rotation_deg
	sky_energy = energy
	sun_gain = sun
	if sun > 0.0:
		horizon_gain = 0.0
	return self

## 追加一批原语（ChapterKit 的返回值可能是单条 Dictionary 或 Array）
func add(items: Variant) -> ChapterData:
	if items is Array:
		for it: Variant in items:
			if it is Dictionary:
				geometry.append(it)
	elif items is Dictionary:
		geometry.append(items)
	return self

## 追加刷怪点。spread 会让刷怪点沿 X 排开，避免全部堆在中轴线上。
func add_spawns(points: Array) -> ChapterData:
	for p: Variant in points:
		spawn_points.append(p as Vector3)
	return self

## 追加一波。growth 是相对上一波的线性增幅，读起来比绝对值直观。
func wave(total: int, max_alive: int, interval: float, special_ratio: float,
		speed: float = 1.0, health: float = 1.0, prepare: float = 2.5,
		rest: float = 4.0) -> ChapterData:
	waves.append({
		"total": total, "max_alive": max_alive, "interval": interval,
		"special_ratio": special_ratio, "speed": speed, "health": health,
		"prepare": prepare, "rest": rest,
	})
	return self

## 自检：返回问题清单（空 = 通过）。构建期直接打印，避免章节数据写错到运行时才发现。
func validate() -> PackedStringArray:
	var errs: PackedStringArray = PackedStringArray()
	if id.is_empty():
		errs.append("id 为空")
	if title.is_empty():
		errs.append("title 为空")
	if geometry.is_empty():
		errs.append("geometry 为空（章节没有任何几何，玩家会掉进虚空）")
	if spawn_points.is_empty():
		errs.append("spawn_points 为空（波次生成器无处刷怪）")
	if waves.is_empty():
		errs.append("waves 为空（关卡永远无法完成）")
	# 刷怪点必须在地面之上，否则丧尸生成瞬间就掉下去
	for i: int in spawn_points.size():
		var p: Vector3 = spawn_points[i]
		if p.y < -1.0:
			errs.append("spawn_points[%d] 的 y=%.2f 低于地面" % [i, p.y])
	# 玩家出生点不能和刷怪点重合，否则开局就被贴脸
	for i: int in spawn_points.size():
		var d: float = Vector2(spawn_points[i].x, spawn_points[i].z).distance_to(
			Vector2(player_start.x, player_start.z))
		if d < 6.0:
			errs.append("spawn_points[%d] 距玩家出生点仅 %.1f 米（<6 会被贴脸）" % [i, d])
	if waves.size() > 12:
		errs.append("waves 超过 12 波（单章过长，节奏失控）")
	return errs

## 章节总击杀数（用于 HUD 进度与难度评估）
func total_kills() -> int:
	var n: int = 0
	for w: Dictionary in waves:
		n += int(w["total"])
	return n
