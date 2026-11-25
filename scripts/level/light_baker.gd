## 构建期光照烘焙器：把「灯的位置」变成「网格顶点色」，运行时不生成任何灯。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么必须烘焙而不是用真灯（实测依据，见 tmp/probe_lights.log）:
##   rendering/limits/opengl/max_lights_per_object = 8
##   rendering/limits/opengl/max_renderable_lights  = 32
##   Compatibility(OpenGL3) 下一个物体最多吃 8 盏灯、整场景最多 32 盏。
##   走廊铺 20 盏吊灯 → 12 盏被静默丢弃，出现「有的灯不亮」的随机暗区，
##   且每多一盏灯就多一份逐像素光照开销。
##   本项目材质是 SHADING_MODE_UNSHADED（贴图即画面），灯本来就不参与着色，
##   所以：灯只在构建期作为数学光源参与顶点色计算，运行时一盏不留。
##   收益 —— 灯数无上限、无每物体限制、无阴影开销、光照完全可复现。
## 材质契约: 使用烘焙色的材质必须 vertex_color_use_as_albedo = true，
##   否则顶点色被丢弃，画面会变成全白平涂。
extends RefCounted

## 半球环境光：法线朝上取 amb_sky，朝下取 amb_ground，中间线性插值。
## 数值由 tmp/light_runner.tscn 与 tmp/lightscan_runner.tscn 联合标定：
##   0.66/0.36 → 地板叠加后冲到 1.000（削顶，贴图细节全丢，画面变塑料白）
##   0.40/0.20 → 地板 0.916、两灯间 0.646，光斑对比 0.27，有层次且留细节
const AMB_SKY: Color = Color(0.40, 0.41, 0.43)
const AMB_GROUND: Color = Color(0.20, 0.196, 0.192)

## 垂直面（墙面）的环境光增益。物理依据：墙面照度 ≈ 水平面照度 × 形状因子，
## 其中大部分来自对面墙与天花的反射，而不是直射灯（灯离墙 8 米，超出 range）。
## 不加这一项，墙面只有 0.30，白墙会读成灰墙，整章偏暗（用户明确说不要太灰暗）。
## 数值标定（tmp/spot_runner.tscn 定点实测，n.y=0 的墙面）：
##   0.60 → wall_right lit=0.473、wall_back lit=0.408，乘 WhiteWall 的 0.773 后
##          只有 0.37 —— 白墙读成中灰（审核实测 rgb(104,101,99)，贴图本身 197/255）
##   1.05 → 墙面环境项 0.30×2.05 = 0.615，墙腰回到 0.60~0.65 的可信区间
## 只影响 |n.y| 小的面：地板/天花 horizon=0 完全不受影响，不会连带把地面推到削顶。
## 回调 1.05 → 0.95：审核员实测同一面白墙上下 lit 跨 2 倍无过渡
##   （右墙上部 lit=0.535 / 下部 lit=0.999 已顶到上限），环境项抬太高会让墙脚撞顶。
## 再回调 0.95 → 1.55（决定性修正）：0.95 时墙面根本吃不到直射光 ——
##   ch01 灯在 x=±3、y=3.25，墙在 x=11，采样点 y=1.8 时距离 8.13 米，
##   而灯 range 只有 6.0，墙面 lit 100% 来自环境项。
##   实测 ch01_03_right 全章最暗 lum=0.294（inner avg rgb(70,77,82)），
##   ch04 三机位 0.381~0.478 —— 白墙读成深灰墙，这就是用户说的「太灰暗」。
##   1.55 时墙腰环境项 = 0.30 × 2.55 = 0.765，乘 WhiteWall 0.773 后 0.59，
##   过后期约 0.62，回到真实白墙在室内灯光下的亮度区间。
##   墙脚有 AO 的 CONTACT_DARK 0.75 压着（0.765×0.75×0.773=0.44），不会撞顶。
const HORIZON_GAIN: float = 1.55

## 实际生效的垂直面增益（默认 = HORIZON_GAIN，由 ChapterBuilder 按章节覆盖）。
##
## **露天章必须调到 0**（决定性实测，tmp/SunProbe.gd）：
##   1.55 是「室内对面墙互反射」的补偿系数，露天根本没有对面墙。
##   ch04 的 ambient_sky=(0.50,0.46,0.42)、ambient_ground=(0.28,0.25,0.23)，
##   垂直面 amb = 中间值 0.39 × 2.55 = **0.994** —— 已经顶到饱和，
##   于是 out = amb + (1-amb)(1-e^-sum) 里 (1-amb) 只剩 0.006，
##   太阳直射项被完全吃掉：实测朝 -X 墙 r=0.914、朝 +X 墙 r=0.914，差 0.000。
##   调到 0 后垂直面 amb = 0.39，留出 0.61 的动态范围给太阳。
static var horizon_gain: float = HORIZON_GAIN

## 地面反弹光：天花板本身不接收直射灯（灯就贴在天花上，半球遮挡全挡掉），
## 真实亮度来自地板反射。实测不加这一项天花只有 0.302，画面里吊顶读成深灰，
## 与"现代明亮大堂"完全相反。这里用一层反弹近似：
##   天花亮度 = 其正下方地板亮度 × 地板反照率 × 增益
## 只做一层（不再递归），开销是一次额外的灯循环，构建期可忽略。
## 数值标定（ch01 审核员同距离对照实测，避开灯槽取 x=170..190/290..310）：
##   天花/地板 = dz6 0.86、dz8 0.82、dz13 0.73 —— 天花恒比地板暗，室内是反的。
##   真实白瓷砖反照率实测 0.92（不是 0.78），反弹增益提到 0.34 后 k=0.313（原 0.203）。
const FLOOR_ALBEDO: float = 0.92
const BOUNCE_GAIN: float = 0.34

## 灯的 wrap 光照系数。纯 N·L 会让侧墙完全吃不到吊灯（灯在头顶正上方，
## 墙面法线与光线夹角接近 90°），实测墙面会掉到 0.05 亮度，看起来像贴图丢了。
## 0.35 的常数项相当于给每盏灯一个「漫射包裹」，墙面亮度回到可用范围。
const WRAP_BASE: float = 0.35

## ── 太阳方向光 ────────────────────────────────────────────────
## 存在理由（ch04 审核报告 P0-6，决定性）：全项目 `scripts\` 下零 DirectionalLight3D，
##   因为所有材质是 SHADING_MODE_UNSHADED，真灯对它们没有任何作用 ——
##   落日只是 skybox 里一张装饰图，场景左右两侧亮度逐位相同
##   （实测区 (20,180)-(150,240) mean=0.532 sd=0.071 与
##     区 (330,180)-(460,240) mean=0.532 sd=0.072 完全一致）。
##   照片级的户外场景必须有方向光：同一面墙上，朝阳与背阳必须是两个亮度。
## 方向推导：天空贴图里太阳在 u=0.69、elev=45.2°，sky_rotation 200°。
##   把「贴图方位」换算到世界坐标后，太阳方向 ≈ (-0.50, 0.70, 0.51)。
##   SUN_DIR 是**从表面指向太阳**的单位向量（与 N·L 的 L 同义）。
const SUN_DIR: Vector3 = Vector3(-0.50, 0.70, 0.51)
## 落日色温：暖橙，不取纯白（纯白会让 ch04 的水泥地读成阴天）。
const SUN_COLOR: Color = Color(1.0, 0.78, 0.52)
## 太阳强度。0.55 时：朝阳面 sum 增量约 0.55×0.7=0.385 → 经指数饱和后
##   反照率抬升约 0.19（约 48/255 级），是可辨但不刺眼的逆光层次。
## 用 static var 而不是给 sample/_direct/build_panel/build_box 各加一个参数：
##   这四项已经是 7~11 个参数，再加一个会让调用点全都要改且极易漏传。
##   ChapterBuilder 在 _run() 开头统一赋值一次，构建是单线程顺序执行，无并发风险。
##   默认 0.0 —— 室内章不显式开启就绝对拿不到太阳光。
static var sun_gain: float = 0.0
## 太阳对半球环境光的调制幅度。
##
## **必须为 0**（实测反效果，不要"优化"回非零值）：
##   能量守恒式是 out = amb + (1-amb)·(1-e^-sum)，amb 出现在**两处**且符号相反 ——
##   抬 amb 会让 (1-amb) 变小，直射项被反向压缩。
##   实测 tmp/SunProbe.gd：SUN_AMB_GAIN=0.25 时朝 -X 的墙面从 r=0.950 **降到 0.944**，
##   即"加了太阳反而更暗"。而地面因为离饱和远，仍从 0.587 升到 0.719，掩盖了这个 bug。
##   方向感交给 sum 里的直射项就够了，它经过同一条能量守恒曲线，不会打架。
const SUN_AMB_GAIN: float = 0.0

## 灯光总增益。指数饱和公式会把弱光压得比线性相加更暗（amb + (1-amb)(1-e^-sum)
## 在 sum 小时 ≈ amb + (1-amb)·sum，比 amb + sum 少了 (1-amb) 那一份），
## 实测 ch01 地板从 0.782 掉到 0.591 —— 用户明确要求「不要太灰暗」，必须补回来。
## 数值由 tmp/bright_runner.tscn 扫描标定：目标 ch01 地板灯下 0.85~0.90、两灯间 0.62~0.68。
## AO 上线后又整体压暗了一档（ch01 全图 lum 0.609→0.534），这里一并补回。
const LIGHT_GAIN: float = 5.2

## ── 接触阴影（AO）────────────────────────────────────────────
## 实现在 light_ao.gd（本文件曾因塞入 AO 涨到 316 行，超出 PDF 300 行红线）。
## 这里只做转发，保持 build_panel/build_box 的签名稳定。
const LightAO := preload("res://scripts/level/light_ao.gd")

## 把章节几何里的实心 box 编成 AO 遮挡网格。空字典 = 不做 AO。
static func build_occluders(geometry: Array) -> Dictionary:
	return LightAO.build(geometry)

## 单点光照采样。返回可直接乘进 albedo 的颜色。
## floor_y 是该场景的地面高度（反弹光用），本项目所有章节地面都在 y=0。
## occluders 由 build_occluders 生成；传空字典时退化为无 AO 的纯光照。
static func sample(p: Vector3, n: Vector3, lamps: Array,
		amb_sky: Color = AMB_SKY, amb_ground: Color = AMB_GROUND,
		floor_y: float = 0.0, occluders: Dictionary = {}) -> Color:
	var acc: Color = _direct(p, n, lamps, amb_sky, amb_ground)
	# 地面反弹光：只给朝下的面（天花板）补。朝上的面本来就被灯直射，不需要。
	# 一层就够 —— 递归第二次的贡献 < 3%，但开销翻倍。
	if n.y < -0.35 and p.y - floor_y > 0.3:
		var lit: Color = _direct(Vector3(p.x, floor_y, p.z), Vector3.UP,
			lamps, amb_sky, amb_ground)
		var k: float = FLOOR_ALBEDO * BOUNCE_GAIN * absf(n.y)
		acc = Color(acc.r + lit.r * k, acc.g + lit.g * k, acc.b + lit.b * k, 1.0)
	# AO 乘在最后：它是遮挡，不是光源，不该参与上面的能量守恒饱和。
	var ao: float = LightAO.at(p, n, occluders, floor_y)
	return Color(_knee(acc.r) * ao, _knee(acc.g) * ao, _knee(acc.b) * ao, 1.0)

## 直接光照（不含反弹）。拆出来是为了让反弹光能复用同一段累加逻辑而不递归。
## 灯的能量用「能量守恒」方式合成，不做简单相加：
##   out = ambient + (1 - ambient) * (1 - exp(-sum))
## 依据：真实表面上多个光源的照度是相加的，但反射出去的总量不可能超过入射能量。
## 简单相加会让灯密的章节（实测 ch02 地板 0.980、ch03 0.918~0.934、ch04 墙面 0.999）
## 整片顶到接近纯白，贴图细节被烧掉 —— 用户说的「塑料感」和「走道白得刺眼」就是这个。
## 指数饱和保证：sum 小时近似线性（保留光斑层次），sum 大时渐近到 1.0（永不削顶）。
static func _direct(p: Vector3, n: Vector3, lamps: Array,
		amb_sky: Color, amb_ground: Color) -> Color:
	var amb: Color = amb_ground.lerp(amb_sky, clampf(n.y * 0.5 + 0.5, 0.0, 1.0))
	# 垂直面补反射光：n.y≈0 时增益最大，天花板/地板不受影响
	var horizon: float = 1.0 - clampf(absf(n.y), 0.0, 1.0)
	var hgain: float = 1.0 + horizon_gain * horizon
	amb = Color(amb.r * hgain, amb.g * hgain, amb.b * hgain, 1.0)
	# 天光方向调制：朝阳的面吃更多天光，背阳的面更暗。
	# 没有这一项，户外场景的地面/墙面会「整片同亮度」，读成平涂贴图
	# （ch04 审核实测左右两区 mean 逐位相同 0.532/0.532）。
	var sun_side: float = n.dot(SUN_DIR)
	amb = Color(amb.r * (1.0 + SUN_AMB_GAIN * sun_side),
		amb.g * (1.0 + SUN_AMB_GAIN * sun_side),
		amb.b * (1.0 + SUN_AMB_GAIN * sun_side), 1.0)
	var sum := Vector3.ZERO
	# 太阳直射项：等效一盏无限远、无衰减的方向灯。
	# 加进 sum 而不是直接加到 out，是为了与室内灯共享同一条能量守恒曲线 ——
	# 否则户外章会绕过 (1-exp(-sum)) 直接顶到削顶。
	# sun_gain 是 static var：室内章保持 0.0，这一段整体为零，行为与改造前完全一致。
	var sun_e: float = sun_gain * maxf(sun_side, 0.0)
	sum += Vector3(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b) * sun_e
	for item: Variant in lamps:
		var l: Dictionary = item as Dictionary
		if l.is_empty():
			continue
		var lp: Vector3 = l["pos"]
		var rng: float = maxf(float(l["range"]), 0.01)
		var d: float = lp.distance_to(p)
		if d >= rng:
			continue
		# 平滑衰减：线性衰减在边界会有硬切线，平方后过渡自然
		var t: float = 1.0 - d / rng
		var atten: float = t * t
		# 吸顶灯 / 落地灯只照下方：灯罩挡住了朝上的光。
		# 不加这一步，紧贴灯下方的天花板会被照到 0.999（削顶成纯白）。
		if bool(l.get("down_only", true)):
			atten *= _hemisphere(p.y - lp.y)
		if atten <= 0.0:
			continue
		var dir: Vector3 = (lp - p) / maxf(d, 0.001)
		var ndl: float = WRAP_BASE + (1.0 - WRAP_BASE) * maxf(n.dot(dir), 0.0)
		var e: float = float(l["energy"]) * atten * ndl * LIGHT_GAIN
		var c: Color = l["color"]
		sum += Vector3(c.r, c.g, c.b) * e
	var out := Vector3(
		amb.r + (1.0 - amb.r) * (1.0 - exp(-sum.x)),
		amb.g + (1.0 - amb.g) * (1.0 - exp(-sum.y)),
		amb.b + (1.0 - amb.b) * (1.0 - exp(-sum.z)))
	return Color(out.x, out.y, out.z, 1.0)

## 半球遮挡：dy = 采样点 - 灯 的 Y 差。dy<0（点在灯下方）返回 1，
## dy>0（点在灯上方）返回 0，中间过渡带做平滑，避免硬边。
##
## 过渡带 0.6 → 1.6（ch01 审核 P0，决定性修正）：
##   吸顶灯挂在 y = H-0.35，天花板在 y = H，**dy 恒为 +0.35**。
##   过渡带 0.6 时 0.5 - 0.35/0.6 = -0.083 → clamp 到 0.000 ——
##   天花对全部 28 盏灯拿到直射光 0，只剩 AMB_SKY(0.40)×WhiteCeiling(0.929) = 0.368。
##   实测（真机后期）天花带 vs 地面带亮度比：ch01 00_player 0.445/0.738（60.3%）、
##   01_center 0.461/0.747（61.7%）、02_back 0.484/0.719（67.3%）、03_right 0.493/0.597（82.6%），
##   单列对照 x=340 天花 0.319 / 地面 0.811（39.3%）—— 天花恒比地面暗 40~60%，
##   而天花占屏高 31.5%，这是"整章偏灰暗"最主要的机械来源。
##   1.6 时 dy=+0.35 得 0.281，天花拿到 28% 的直射，亮度比回到 80% 左右，
##   符合"白色吊顶被上方灯槽照亮"的真实观感。
## 为什么不干脆让吸顶灯全向照：灯罩挡住朝上的光是真的（物理上确实不该亮），
##   但本项目的灯是"灯槽 + 发光面"结构，光会从槽口溢出打亮槽边天花，
##   纯半球模型丢掉了这部分，只能靠放宽过渡带近似。
const HEMI_BAND: float = 1.6

static func _hemisphere(dy: float) -> float:
	return clampf(0.5 - dy / HEMI_BAND, 0.0, 1.0)

## 高光软压缩。硬 clamp 到 1.0 会把 >1 的区域全部烧成同一片纯白，
## 贴图细节（地砖缝、石材纹路）彻底消失 —— 这就是"塑料感"的来源。
## 实测：25 盏灯叠加后地板/柱面/前墙/天花全部顶到 1.000。
## 这里只压 0.78 以上的部分，中间调完全不动，高光区仍保留 0.78→0.99 的梯度。
static func _knee(v: float) -> float:
	if v <= 0.78:
		return v
	var over: float = v - 0.78
	return 0.78 + 0.22 * (1.0 - exp(-over / 0.22))

## ── 几何生成转发 ──────────────────────────────────────────────
## 实现在 mesh_builder.gd（本文件加入太阳方向光后涨到 412 行，超出 PDF 300 行红线）。
## 这里只做转发，保持 build_panel/build_box 的签名与调用点不变。
## 用 static func 包一层而不是 `const MeshBuilder := preload(...)` 后直接 alias：
##   mesh_builder 需要 preload light_baker 才能调 sample()，若这边也 preload
##   mesh_builder 会形成循环依赖（GDScript 直接报 Cyclic reference）。
##   延迟到函数体内 load() 可以打破这个环，且构建期只调用几十次，开销可忽略。
static func axes(axis: String) -> Array:
	return load("res://scripts/level/mesh_builder.gd").axes(axis)

static func build_panel(center: Vector3, size: Vector2, axis: String,
		lamps: Array, tint: Color, step: float = 1.0,
		amb_sky: Color = AMB_SKY, amb_ground: Color = AMB_GROUND,
		tiled: bool = true, emissive: bool = false,
		occluders: Dictionary = {}) -> ArrayMesh:
	return load("res://scripts/level/mesh_builder.gd").build_panel(
		center, size, axis, lamps, tint, step, amb_sky, amb_ground,
		tiled, emissive, occluders)

static func build_box(center: Vector3, size: Vector3, lamps: Array, tint: Color,
		step: float = 1.0, amb_sky: Color = AMB_SKY,
		amb_ground: Color = AMB_GROUND, occluders: Dictionary = {}) -> ArrayMesh:
	return load("res://scripts/level/mesh_builder.gd").build_box(
		center, size, lamps, tint, step, amb_sky, amb_ground, occluders)
