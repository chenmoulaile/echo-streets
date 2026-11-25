## 章节构建器：把 ChapterData 的几何原语翻译成真实节点，并把灯烘焙进顶点色。
## 挂载节点类型: 无（extends RefCounted，静态入口 build()）
## 依赖: light_baker.gd（顶点色烘焙）、chapter_kit.gd（原语工厂）、GameLayers
## 存在理由: 4 章若各写一份建场逻辑，改一次光照参数要改四遍且必然漂移。
##   这里只写一次翻译逻辑，章节差异全部收在数据里。
## 材质契约（关键，改错就整片发白）:
##   1. vertex_color_use_as_albedo = true —— 否则顶点色被丢弃，烘焙白做；
##   2. shading_mode = UNSHADED —— 场景没有运行时灯，光照全靠顶点色；
##   3. uv1_triplanar + uv1_scale 0.5 —— 200px 材质铺 2 米，接缝自然；
##   4. texture_filter = NEAREST —— 保住像素风的硬边。
## 碰撞契约: panel 与 box 都建 StaticBody3D（layer = WORLD），透明件除外。
##   地板/天花板必须挡 hitscan，否则子弹穿地打到虚空。
extends RefCounted

const LightBaker := preload("res://scripts/level/light_baker.gd")
## 显式 preload 类型：GDScript 对静态类型变量做成员检查，
## 参数写成 RefCounted 时 data.lamps 会直接报「Cannot find member in base RefCounted」。
const ChapterDataScript := preload("res://scripts/level/chapter_data.gd")
const MAT_DIR := "res://assets/materials/"
const WORLD_LAYER := 1

## 材质缓存：同一张贴图 + 同一透明度只建一个 StandardMaterial3D。
## 一章有几百个 box，不缓存会建几百个材质实例，每帧都要重绑定贴图。
var _mat_cache: Dictionary = {}
var _lamps: Array = []
var _amb_sky: Color = LightBaker.AMB_SKY
var _amb_ground: Color = LightBaker.AMB_GROUND
var _step: float = 1.0
## 接触阴影遮挡体索引（build_occluders 生成）。空字典 = 不做 AO。
var _occluders: Dictionary = {}
## 统计（构建日志用，方便确认"这章真的建出来了"而不是静默空场景）
var _n_mesh: int = 0
var _n_body: int = 0
var _n_tri: int = 0

## 主入口：把 data 的所有原语挂到 parent 下。返回统计字典。
static func build(data: ChapterDataScript, parent: Node3D) -> Dictionary:
	var b := new()
	return b._run(data, parent)

func _run(data: ChapterDataScript, parent: Node3D) -> Dictionary:
	_lamps = data.lamps
	_amb_sky = data.ambient_sky
	_amb_ground = data.ambient_ground
	_step = maxf(data.mesh_step, 0.25)
	# 太阳方向光是 LightBaker 的 static var（不随调用点传参，见那边的注释）。
	# 必须在这里、建任何几何之前赋值：顶点色是在建网格时一次性算好的。
	LightBaker.sun_gain = data.sun_gain
	LightBaker.horizon_gain = data.horizon_gain if data.horizon_gain >= 0.0 \
		else LightBaker.HORIZON_GAIN
	# 遮挡体必须在建几何之前算好：AO 是顶点色的输入，不是后处理。
	_occluders = LightBaker.build_occluders(data.geometry)
	for item: Variant in data.geometry:
		var g: Dictionary = item as Dictionary
		if g.is_empty():
			continue
		match String(g["k"]):
			"panel":
				_add_panel(g, parent)
			"box":
				_add_box(g, parent)
			"solid":
				# 纯碰撞：只挡玩家与 hitscan，不产生任何可见几何。
				_add_body(parent, "Solid_%d" % _n_body, g["pos"], g["size"])
			_:
				push_warning("ChapterBuilder: 未知原语 %s" % g["k"])
	return {
		"meshes": _n_mesh, "bodies": _n_body, "tris": _n_tri,
		"lamps": _lamps.size(), "materials": _mat_cache.size(),
	}

## 平面：细分网格 + 逐顶点烘焙 + 薄碰撞体（0.2 米厚，足够挡 hitscan 与角色）
func _add_panel(g: Dictionary, parent: Node3D) -> void:
	var center: Vector3 = g["pos"]
	var size: Vector2 = g["size"]
	var axis: String = g["axis"]
	var emissive: bool = bool(g.get("emissive", false))
	var mesh: ArrayMesh = LightBaker.build_panel(center, size, axis, _lamps,
		g["tint"], g["step"], _amb_sky, _amb_ground, bool(g.get("tiled", true)), emissive,
		_occluders)
	var mi := MeshInstance3D.new()
	mi.name = "Panel_%d" % _n_mesh
	mi.mesh = mesh
	# 发光面必须关掉三平面平铺：uv1_triplanar 会忽略网格自带的 UV 数组，
	# 改由世界坐标现算 UV。灯位 z 全是 6 的倍数 → v=z*0.5 恒为整数，
	# NEAREST 采样正好压在 WhiteCeiling_MetalEdge 的第 0 行蓝灰边框（实测 rgb(145,169,179)），
	# 21 盏灯全部渲染成边框色，灯槽读成"天花上一道深灰长条"。
	# 关掉平铺后 build_panel 给发光面写的是常量 UV (0.5,0.5)，取贴图正中内芯 rgb(230)。
	var panel_tiled: bool = bool(g.get("tiled", true)) and not emissive
	mi.material_override = _material(g["mat"], g["tint"], 1.0, panel_tiled)
	parent.add_child(mi)
	_n_mesh += 1
	_n_tri += int(size.x * size.y / (_step * _step)) * 2
	# 碰撞：把平面当成一块薄板。up/down 厚度在 Y，z± 在 Z，x± 在 X。
	# 发光面（emissive）**不建碰撞**：它们全是贴在天花/墙上的灯罩面，
	#   玩家永远够不到，建了就是纯浪费。ch02 审核实测 21 个发光面 panel
	#   各建了一块 (2.0,0.2,0.30) 的碰撞体悬在 y=3.115，占 bodies 的 9.5%。
	#   而且这类碰撞体在俯视机位会把天花渲染出一层"看不见的实体"，
	#   与"灯是发光的薄面"这个视觉事实矛盾。
	if not emissive:
		var t: float = 0.2
		var box_size: Vector3 = Vector3(size.x, t, size.y) if axis == "up" or axis == "down" else (
			Vector3(size.x, size.y, t) if axis.begins_with("z") else Vector3(t, size.y, size.x))
		_add_body(parent, "Body_%d" % _n_body, center, box_size)

## 方块：六面烘焙 + 实心碰撞。透明件（玻璃）不建碰撞，否则变成看不见的墙。
## step=0 表示"用章节默认步长"；大于 0 时按条目覆盖 ——
##   柱子这类需要硬棱角的小体积物体必须用更小的步长，否则顶点色被
##   Gouraud 插值抹成圆柱（详见 chapter_kit.box 的注释）。
func _add_box(g: Dictionary, parent: Node3D) -> void:
	var center: Vector3 = g["pos"]
	var size: Vector3 = g["size"]
	var alpha: float = g["alpha"]
	var local_step: float = float(g.get("step", 0.0))
	var use_step: float = local_step if local_step > 0.0 else _step
	var mesh: ArrayMesh = LightBaker.build_box(center, size, _lamps, g["tint"],
		use_step, _amb_sky, _amb_ground, _occluders)
	var mi := MeshInstance3D.new()
	mi.name = "Box_%d" % _n_mesh
	mi.mesh = mesh
	mi.material_override = _material(g["mat"], g["tint"], alpha)
	# 旋转（度）：太阳能板/扶梯这类斜置构件必须真的转网格。
	#
	# **致命陷阱（已实测）**：light_baker.build_box 生成的顶点是**世界坐标**
	#   （顶点色要按世界位置采样灯光，不能做成局部坐标），所以 MeshInstance3D
	#   的 transform 必须是单位阵。直接写 `mi.rotation_degrees = rot` 会让网格
	#   绕**世界原点**旋转，而不是绕自身中心：
	#   ch04 太阳能板 (10.2, 0.73, -11.4) 绕世界 X 轴转 12° → 实际落到
	#   y≈3.08、z≈-11.0，整排板被抬到 3 米高空，而"前矮柱后高柱"的柱子还留在原地。
	# 正解：套一层 pivot 节点放在 center 上承担旋转，网格实例用 -center 抵消平移：
	#   T(center) · R · T(-center) · v = R·(v - center) + center，正是绕自身中心转。
	var rot: Vector3 = g.get("rot", Vector3.ZERO)
	if rot != Vector3.ZERO:
		var pivot := Node3D.new()
		pivot.name = "Pivot_%d" % _n_mesh
		pivot.position = center
		pivot.rotation_degrees = rot
		mi.position = -center
		pivot.add_child(mi)
		parent.add_child(pivot)
	else:
		parent.add_child(mi)
	_n_mesh += 1
	_n_tri += int((size.x * size.y + size.y * size.z + size.x * size.z) * 2.0
		/ (use_step * use_step))
	# 碰撞体不跟着转：斜板是可绕过的装饰，旋转 AABB 会变成一块斜插进地面的碰撞体，
	# 玩家会被"看不见的斜墙"挡住。斜板一律 body=false（见 chapter_04 的调用）。
	if bool(g["body"]):
		_add_body(parent, "Body_%d" % _n_body, center, size)

func _add_body(parent: Node3D, node_name: String, center: Vector3,
		size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	_n_body += 1

## 材质工厂。key 里带 alpha 与 tiled —— 同一张图既可能平铺也可能整面展开，
## 两者 UV 语义不同，不能共用同一个材质实例。
func _material(tex_name: String, tint: Color, alpha: float,
		tiled: bool = true) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%s" % [tex_name, alpha, str(tiled)]
	var hit: StandardMaterial3D = _mat_cache.get(key)
	if hit != null:
		return hit
	var m := StandardMaterial3D.new()
	var path: String = MAT_DIR + tex_name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
		m.albedo_texture = tex
	else:
		push_warning("ChapterBuilder: 材质缺失 %s（退化为纯色块）" % path)
	# 顶点色承载烘焙光照；关掉它整章会变成没有明暗的平涂
	m.vertex_color_use_as_albedo = true
	# 场景里没有任何运行时灯，走 unshaded 才能让顶点色原样输出
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# NEAREST + 无 mipmap 会让远处缩小采样时随机命中板缝像素，整片地面变成"撒了黑芝麻"
	# （实测 ch02 俯视图木地板满屏孤立黑点）。改用 NEAREST_WITH_MIPMAPS：近景仍是硬边像素风，
	# 远景自动降采样到合适 mip 层，板缝平均成连续的细线而不是噪点。
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	# 三平面平铺只对"墙地砖"有意义。天空板/屏幕/门板这类有构图的大图必须关掉，
	# 否则会被平铺成重复图案（实测天空板铺成了"一排橙色方块"）。
	if tiled:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	m.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	# 透明通道要不要开，取决于「贴图本身有没有 alpha」而不只是章节传的 alpha。
	# 依据（实测 ch04 玻璃栏板）：Glass.png 的 p50 alpha 只有 26/255=0.102，
	# 整张图的不透明度信息全在贴图 alpha 通道里。章节按"传 1.0 让贴图自己决定"
	# 的写法传 1.0 时，旧条件 `alpha < 1.0` 不成立 → TRANSPARENCY_DISABLED
	# → 引擎彻底忽略贴图 alpha → 玻璃渲染成不透明 #C3EFFC 青白板
	# （实测 y=138 rgb(187,234,249) L=0.883，比背后天空 0.651 还亮 0.23）。
	# 所以这里改成"章节 alpha 未满 或 贴图自带 alpha"任一成立就开透明。
	var tex_has_alpha: bool = tex != null and tex.get_image().detect_alpha() != Image.ALPHA_NONE
	if alpha < 1.0 or tex_has_alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# 半透明面不写深度。
		# 依据（实测 ch04 玻璃栏板）：默认 DEPTH_DRAW_OPAQUE 会让玻璃把身后
		# 的天空/远景深度挡住，混合阶段拿不到背景色，28% alpha 的玻璃
		# 在截帧里读成一道 L<20 的黑色实心矮墙（连续 25 行纯黑）。
		# 关掉深度写入后玻璃只做颜色混合，才读得出"透明栏板 + 后面是天空"。
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat_cache[key] = m
	return m

## 刷怪点：建 Marker3D 节点供 WaveSpawner 找。
static func build_spawns(data: ChapterDataScript, parent: Node3D) -> int:
	var holder := Node3D.new()
	holder.name = "SpawnPoints"
	parent.add_child(holder)
	return fill_spawns(data, holder)

## 把刷怪点填进已存在的 holder。
## 换章必须走这条而不是 build_spawns：WaveSpawner 的 _spawn_points_root 是
## @onready 缓存的引用，把 SpawnPoints 整个换掉会让它指向已释放的节点，
## 之后 _pick_spawn_position 遍历到空数组，每只丧尸都掉到环形兜底位。
static func fill_spawns(data: ChapterDataScript, holder: Node3D) -> int:
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.free()
	var n: int = 0
	for p: Variant in data.spawn_points:
		var mk := Marker3D.new()
		mk.name = "Spawn_%d" % n
		mk.position = p as Vector3
		holder.add_child(mk)
		n += 1
	return n

## 全景天空。返回 true 表示建了 WorldEnvironment，false 表示本章不要天空。
## 为什么用 PanoramaSkyMaterial 而不是四面天空板：
##   天空板是平面，抬头/低头会看到板的边缘与接缝；而且板本身要被顶点色烘焙，
##   等于给"太阳"打了一个假的明暗。真 skybox 由 GPU 按方向采样，无接缝、无边界、
##   且能作为环境光来源（ambient_light_source = SKY）——天台这类开放场景必须这样。
## Compatibility(OpenGL3) 已实测支持（tmp/SkyProbe.gd，四方向截图均正常）。
## 旋转为什么用自定义 shader：PanoramaSkyMaterial 没有 rotation，
##   WorldEnvironment 又不是 Node3D（没有 rotation），只能把旋转写成 sky shader 的 uniform。
static func build_sky(data: ChapterDataScript, parent: Node3D) -> bool:
	if data.sky_texture.is_empty():
		return false
	if not ResourceLoader.exists(data.sky_texture):
		push_warning("ChapterBuilder: 天空贴图缺失 %s（本章退回纯色背景）" % data.sky_texture)
		return false
	var we := WorldEnvironment.new()
	we.name = "Sky"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var shader: Shader = load("res://shaders/panorama_sky_rot.gdshader")
	if shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter(&"panorama", load(data.sky_texture))
		sm.set_shader_parameter(&"rotation_deg", data.sky_rotation_deg)
		sm.set_shader_parameter(&"exposure", 1.0)
		# 地平线以下压暗 0.72：俯瞰城市是暗雾，不是原图那片亮黄沙地
		sm.set_shader_parameter(&"below_horizon_darken", 0.72)
		sky.sky_material = sm
	else:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(data.sky_texture)
		sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	# 天空同时当环境光：天台地面只有太阳照，不从这里补光下半屏会死黑。
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = data.sky_energy
	# FILMIC 而不是 ACES：ACES 会把落日橙压成土黄，暖色高光全丢。
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	we.environment = env
	parent.add_child(we)
	return true

