## 章节几何原语工具箱（**构建期**使用，运行时不加载）
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么不用 class_name: 本文件只被 tmp/BuildWorld.gd 与章节定义文件 preload，
##   走 global_script_class_cache 反而要依赖一次完整 --import 才能解析类型。
## 设计: 章节文件只"描述长什么样"（返回原语字典数组），ChapterBuilder 负责把
##   原语翻译成节点、把灯光烘焙进顶点色。数据与机制分离，加一章不改构建器。
##
## 为什么用「网格 + 顶点色烘焙」而不是真灯：
##   实测 rendering/limits/opengl/max_lights_per_object = 8、
##   max_renderable_lights = 32（tmp/probe_lights.log）。Compatibility 渲染器下
##   一个物体最多吃 8 盏灯、整个场景最多 32 盏，走廊里铺 20 盏吊灯就会有 12 盏
##   被静默丢弃，出现"有的灯不亮"的死角。而本项目材质是 SHADING_MODE_UNSHADED，
##   灯对它们本来就没有影响 —— 真正决定明暗的是 albedo。
##   所以：灯只在构建期作为数学光源参与顶点色计算，运行时一个 OmniLight3D 都不留。
##   好处是灯数无上限、无每物体限制、无阴影开销，且光照完全可复现。
extends RefCounted

const MAT_DIR := "res://assets/materials/"

## 材质名 → res:// 路径。章节里只写 WhiteWall 这类短名。
static func m(name: String) -> String:
	return MAT_DIR + name + ".png"

## 通用实心方块（带碰撞）。用于柱子、家具、墙裙、过梁。
## alpha < 1.0 时走透明混合且强制 body=false —— 透明碰撞体会挡住视线却看不见，
## 玩家会撞到"空气墙"。
## step 是逐面细分步长（米）。默认 1.0；**大尺寸或需要硬棱角的物体必须调小**：
##   柱子 1.1x3.6x1.1 用 step=1.0 时每个面只有 2x4 个顶点，Gouraud 插值会把
##   四条竖棱抹成连续渐变，实测渲染出来像一根圆柱而不是方柱（tmp/shots/crop_col.png）。
##   step=0.4 后每面 3x9 顶点，棱角才立得住。
## rot 是绕各轴的旋转（度）。加这个参数的唯一理由是太阳能板：
##   初版靠「前柱矮后柱高」假装倾斜，但板本身是水平薄板 —— 审核实测
##   ch04_03_right 逐列扫板顶边，跨 200px 只升 6px（真 12° 倾斜应有 ≥20px），
##   且前柱顶 0.68 与板框底 0.76 之间留着 0.08 米空隙（柱子没顶到板）。
##   只有真的旋转网格，斜面和柱子接触关系才对得上。
## 注意：顶点色是在**未旋转**的局部空间烘焙的。对薄板来说法线偏差 ≤12°，
##   亮度误差在 3% 以内，肉眼不可辨；旋转超过 30° 的大物体要另行处理。
static func box(size: Vector3, pos: Vector3, mat: String, tint: Color = Color.WHITE,
		body: bool = true, alpha: float = 1.0, step: float = 0.0,
		rot: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"k": "box", "size": size, "pos": pos, "mat": mat, "tint": tint,
		"body": body and alpha >= 1.0, "alpha": alpha, "step": step, "rot": rot}

## 纯碰撞体：只建 StaticBody3D，不建网格、不参与烘焙、不当 AO 遮挡物。
## 用于「视觉上必须是通透的，但玩家绝不能穿过去」的位置。
## 为什么需要（ch01 审核 P0-2 实测依据）：
##   左墙幕墙的玻璃是 box(..., body=false) —— 透明件不建碰撞，否则变隐形墙；
##   墙裙只到 y=0.90，而 player 的 jump_velocity=5.0 对应跳高 1.276 米，
##   玩家从 0.90 以上的玻璃段直接跳出世界（全项目无 kill_plane 兜底）。
##   这类"看得穿但不能穿"的面必须靠不可见的碰撞体挡住。
static func solid(size: Vector3, pos: Vector3) -> Dictionary:
	return {"k": "solid", "size": size, "pos": pos}

## 细分平面 + 逐顶点烘焙光照。axis 决定朝向：
##   "up"   地板（法线 +Y）        "down" 天花板（法线 -Y）
##   "z+"   朝 +Z 的墙             "z-"   朝 -Z 的墙
##   "x+"   朝 +X 的墙             "x-"   朝 -X 的墙
## center 是平面中心，size 是平面尺寸（axis 为 up/down 时 size=(X,Z)，
## 为 z± 时 size=(X,Y)，为 x± 时 size=(Z,Y)）。
## step 是网格边长（米）：1.0 时光池边缘平滑，2.0 时块感明显但顶点数减半。
## tiled=false 时关闭三平面平铺、按整面 UV(0..1) 展开 —— 天空板/屏幕/门板这类
##   有明确构图的大图必须这么贴，否则会被平铺成一格格重复图案（实测天空板
##   就被铺成了"一排橙色方块"，完全读不出是窗外落日）。
## emissive=true 表示这块面**自己发光**（灯具发光面、灯箱、屏幕亮面）：
##   顶点色直接用 tint，不参与光照烘焙。不加这个开关时发光面会被烘焙光照
##   压到 0.6 左右，实测比周围天花还暗（rgb 137 vs 173），灯读成了"顶上一块脏板"。
static func panel(center: Vector3, size: Vector2, axis: String, mat: String,
		tint: Color = Color.WHITE, step: float = 1.0, tiled: bool = true,
		emissive: bool = false) -> Dictionary:
	return {"k": "panel", "pos": center, "size": size, "axis": axis, "mat": mat,
		"tint": tint, "step": step, "tiled": tiled, "emissive": emissive}

## 吊顶灯：只登记为**构建期光源**，运行时不产生任何节点。
## 灯面板本身由调用方用 panel("down", ...) 单独铺一块自发光材质。
## down_only=true 表示灯罩挡住朝上的光（吸顶灯/吊灯都这样），
##   false 用于天空板这类"整面发光"的补光，它要照亮上下两侧。
static func lamp(pos: Vector3, color: Color, energy: float,
		range_m: float = 11.0, down_only: bool = true) -> Dictionary:
	return {"k": "lamp", "pos": pos, "color": color, "energy": energy,
		"range": range_m, "down_only": down_only}

## 一排吊顶灯（只登记光源）。along_z=true 沿 Z 铺，否则沿 X 铺。
static func lamp_row(center: Vector3, count: int, step: float, along_z: bool,
		color: Color, energy: float, range_m: float = 11.0) -> Array:
	var out: Array = []
	for i: int in count:
		var t: float = (float(i) - float(count - 1) * 0.5) * step
		var p: Vector3 = center + (Vector3(0.0, 0.0, t) if along_z else Vector3(t, 0.0, 0.0))
		out.append(lamp(p, color, energy, range_m))
	return out

## 玻璃幕墙：墙裙 + 玻璃 + 过梁 + 竖挺。axis = "x" 表示墙沿 X 延伸。
## 玻璃用 alpha 混合且无碰撞；竖挺给"分格"的现代幕墙观感。
static func curtain(out: Array, center: Vector3, length: float, height: float,
		axis: String, frame_mat: String, glass_mat: String,
		sill: float = 0.85, header: float = 0.5) -> void:
	var along_x: bool = axis == "x"
	var base: float = center.y - height * 0.5
	var top: float = center.y + height * 0.5
	var gy0: float = base + sill
	var gy1: float = top - header
	var gy: float = (gy0 + gy1) * 0.5
	var gh: float = gy1 - gy0
	if gh > 0.2:
		if along_x:
			out.append(box(Vector3(length, gh, 0.08), Vector3(center.x, gy, center.z),
				glass_mat, Color(0.88, 0.95, 1.0), false, 0.30))
		else:
			out.append(box(Vector3(0.08, gh, length), Vector3(center.x, gy, center.z),
				glass_mat, Color(0.88, 0.95, 1.0), false, 0.30))
	if sill > 0.05:
		if along_x:
			out.append(box(Vector3(length, sill, 0.42),
				Vector3(center.x, base + sill * 0.5, center.z), frame_mat))
		else:
			out.append(box(Vector3(0.42, sill, length),
				Vector3(center.x, base + sill * 0.5, center.z), frame_mat))
	if header > 0.05:
		if along_x:
			out.append(box(Vector3(length, header, 0.42),
				Vector3(center.x, top - header * 0.5, center.z), frame_mat))
		else:
			out.append(box(Vector3(0.42, header, length),
				Vector3(center.x, top - header * 0.5, center.z), frame_mat))
	# 竖挺：每 2 米一根，读得出幕墙分格而不是一整块塑料板
	var panes: int = maxi(int(round(length / 2.0)), 1)
	for i: int in panes + 1:
		var t: float = -length * 0.5 + length * float(i) / float(panes)
		if along_x:
			out.append(box(Vector3(0.13, gh, 0.26),
				Vector3(center.x + t, gy, center.z), frame_mat, Color(0.94, 0.96, 0.98)))
		else:
			out.append(box(Vector3(0.26, gh, 0.13),
				Vector3(center.x, gy, center.z + t), frame_mat, Color(0.94, 0.96, 0.98)))

## 天花灯带：一整条自发光长条（panel 朝下，浅色 tint）。
static func light_strip(out: Array, center: Vector3, size: Vector2,
		color: Color = Color(1.0, 0.98, 0.92)) -> void:
	out.append(panel(center, size, "down", "WhiteCeiling_MetalEdge", color, 2.0))

## 吊顶分缝格栅：沿一个方向铺一排细梁，把大天花切成一块块板。
## 为什么必须有：WhiteCeiling 贴图平均色 #EDEDED 且细节极少（几乎纯白），
##   整片 22x46 米铺上去再被 mipmap 抹平，读成「一团模糊的云雾」而不是
##   「装出来的吊顶」（实测 4x 放大 tmp/shots/crop_ceil.png 就是这样）。
##   真实吊顶靠"板缝 + 分格梁"给出尺度感，光靠贴图给不出来。
## axis="z" 表示梁沿 Z 延伸（在 X 方向排布），"x" 反之。
## 梁高 0.06 米、宽 0.10 米 —— 太宽会读成结构梁，太细看不见。
##
## 中轴跳过：梁沿 Z 延伸且落在 x≈0 时，玩家站在中轴上沿 -Z 看，
##   这根梁在屏幕上正好投影成一条贯穿上下的竖线，读成"画面被劈开"
##   （实测 ch01_01_center / 01_idle 都有这条线，先是误判成中轴灯带，
##   删掉灯带后线仍在，才定位到格栅梁）。几何上任何沿视线轴且过视点的
##   细长物体都会这样，只能跳过。
## 返回原语数组，调用方用 d.add(...) 收进去。
static func ceiling_grid(center: Vector3, span: Vector2, axis: String, step: float,
		drop: float = 0.06, mat: String = "MetalPlateWall",
		tint: Color = Color(0.72, 0.74, 0.78)) -> Array:
	var out: Array = []
	var along_z: bool = axis == "z"
	var length: float = span.y if along_z else span.x
	var across: float = span.x if along_z else span.y
	var count: int = maxi(int(round(across / maxf(step, 0.5))), 1)
	for i: int in count + 1:
		var t: float = -across * 0.5 + across * float(i) / float(count)
		# 沿视线轴的梁若压在中轴上，会投影成一条劈开画面的竖线
		if along_z and absf(center.x + t) < 0.6:
			continue
		# 同理：梁沿 X 延伸且落在 z≈0 时，玩家站在中轴朝 -Z 看，这根梁横跨视线中心，
		# 投影成画面正中的一条暗带（审核实测 00_player x=300 竖剖面暗谷 y=114..116，
		# 与 z=0 梁距机位 18 米、梁底 y=3.515 的解析投影 sy=116.3 完全吻合）。
		if not along_z and absf(center.z + t) < 0.6:
			continue
		var p: Vector3 = center + (Vector3(t, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, t))
		if along_z:
			out.append(box(Vector3(0.10, drop, length), p, mat, tint, false))
		else:
			out.append(box(Vector3(length, drop, 0.10), p, mat, tint, false))
	return out

## 地面铺装缝：把整片地面切成一块块石材，给出尺度感与透视节奏。
## 为什么必须有：CeramicFloor_White 铺满 22x46 米后，贴图自带的砖缝是
##   世界 2 米一格、宽约 2 厘米，在 480x270 下被 mipmap 抹成一层灰雾，
##   读成"一整块白塑料"而不是"抛光石材地面"（ch01 审核 P1 第 6 条）。
##
## 与 ceiling_grid 的关键区别：天花梁在眼睛高度上方，沿视线轴延伸时
##   必然投影成劈开画面的竖线；地面缝躺在 y=0 平面上，沿 Z 延伸时正常
##   收敛到消失点，是透视该有的样子。**但正中那条仍要跳过** —— 世界
##   x=0 的缝会正好压在屏幕中轴上（ch02 中轴竖线就是这个形态，实测
##   18.9 灰阶差），读成"画面被一条线劈开"。
##
## 抬到 y=0.006：与地面 panel 共面会 Z-fight，0.006 米在 1.6 米眼高下
##   不到半个像素，不会读成"浮起来的地毯边"。
static func floor_seams(center: Vector3, span: Vector2, step: float,
		mat: String = "CeramicFloor_White", tint: Color = Color(0.70, 0.72, 0.76),
		width: float = 0.04) -> Array:
	var out: Array = []
	var y: float = center.y + 0.006
	var nx: int = maxi(int(round(span.x / maxf(step, 0.5))), 1)
	var nz: int = maxi(int(round(span.y / maxf(step, 0.5))), 1)
	for i: int in nx + 1:
		var x: float = center.x - span.x * 0.5 + span.x * float(i) / float(nx)
		if absf(x) < 0.6:
			continue
		out.append(panel(Vector3(x, y, center.z), Vector2(width, span.y), "up",
			mat, tint, 1.0))
	for j: int in nz + 1:
		var z: float = center.z - span.y * 0.5 + span.y * float(j) / float(nz)
		if absf(z) < 0.6:
			continue
		out.append(panel(Vector3(center.x, y, z), Vector2(span.x, width), "up",
			mat, tint, 1.0))
	return out

## 墙面石材分缝：把整面墙切成一块块挂板，给出尺度感。
## 为什么必须有：WhiteWall 贴图平均色 #C4C4C4 且几乎无花纹，22x46 米整面
##   铺开后在近景读成"一整片白灰"，审核实测 ch01 右墙近景上半 0.403~0.546、
##   全帧最暗，却没有任何结构可看 —— 亮度不是问题，**没有东西可看**才是。
## 真实现代商业空间的墙面是石材/铝板挂板，靠竖向分缝给出 1.2 米模数。
##
## axis 与 panel 一致：墙在 z=±HALF_L 用 "z+"/"z-"，在 x=±HALF_W 用 "x+"/"x-"。
## 缝离墙 0.012 米（避免与墙面共面 Z-fight），宽 0.03 米、高到墙顶。
## 竖向缝只铺一个方向：横向分缝在 1.6 米眼高下会与天花格栅、踢脚线抢层次。
static func wall_seams(wall_center: Vector3, wall_size: Vector2, axis: String,
		step: float, mat: String = "WhiteWall",
		tint: Color = Color(0.62, 0.63, 0.66), width: float = 0.03) -> Array:
	var out: Array = []
	var outward: Vector3 = Vector3.ZERO
	match axis:
		"z+": outward = Vector3(0.0, 0.0, 1.0)
		"z-": outward = Vector3(0.0, 0.0, -1.0)
		"x+": outward = Vector3(1.0, 0.0, 0.0)
		"x-": outward = Vector3(-1.0, 0.0, 0.0)
		_: return out
	# 沿墙的横向轴：z± 墙横向是 X，x± 墙横向是 Z
	var along_z: bool = axis.begins_with("x")
	var span: float = wall_size.x if along_z else wall_size.y
	var n: int = maxi(int(round(span / maxf(step, 0.5))), 1)
	for i: int in n + 1:
		var t: float = -span * 0.5 + span * float(i) / float(n)
		# 沿视线轴的中轴缝会投影成贯穿画面的竖线（同 ceiling_grid / floor_seams）
		if along_z and absf(wall_center.z + t) < 0.6:
			continue
		if not along_z and absf(wall_center.x + t) < 0.6:
			continue
		var c: Vector3 = wall_center + outward * 0.012
		c += Vector3(0.0, 0.0, t) if along_z else Vector3(t, 0.0, 0.0)
		var size: Vector2 = Vector2(width, wall_size.y) if along_z else Vector2(width, wall_size.y)
		out.append(panel(c, size, axis, mat, tint, 1.0))
	return out
