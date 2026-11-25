## 接触阴影（AO）采样器：把「物体挡住环境光」变成顶点色的一个乘数。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么必须有 AO（实测依据）:
##   照片级画面的第一特征是「物体与地面接触处有一圈暗」，不是亮度均匀。
##   本项目四章截帧全图统计（tmp/Audit.cs）显示亮度标准差 sd 只有 0.09~0.17，
##   且墙脚亮度 ≈ 墙腰亮度（ch04 两者都是 0.918）—— 物理上是反的。
##   真实室内墙脚被地面与家具挡住大半环境光，必然比墙腰暗一档以上。
##   没有 AO 时画面读成「平面贴图拼起来的盒子」，这是「不像照片」的主因。
## 实现取舍:
##   不递归、不射线、不屏幕空间。构建期把每个实心 box 登记进三维网格，
##   采样点按 AO_RADIUS 找 3x3x3 邻域，用「到 AABB 表面的距离」算遮挡量。
##   用网格而不是全表遍历：一章 100+ 个 box × 上千个顶点，全表是百万级距离计算。
## 只收 body=true 的 box:
##   地板/天花板/墙是 panel（薄板），把它们当遮挡物会让整片地面自己压暗自己，
##   反而比不加 AO 更假。
extends RefCounted

## 遮挡半径（米）。也是三维网格的 cell 边长，改它必须同步改 _occluders_near 的邻域范围。
const AO_RADIUS: float = 1.6
## 遮挡最多压掉多少亮度。0.55 让柱子根部明显发暗但不会出现「黑圈」。
const AO_STRENGTH: float = 0.55
## 墙脚接触阴影的衰减高度（米）与最暗系数。
## 依据（ch01 审核员逐行实测，截图 ch01_03_right.png）：
##   1.1 米 / 0.58 时，右墙脚 y=180..228 整段 dark<38 占 20~30%、纯 0 像素 22~27%，
##   而同墙墙腰正常 —— 不是「有阴影」而是「成片死黑」，读成墙根烂掉。
##   链路：踢脚线 tint(0.48,0.50,0.54) × MetalWall albedo 0.312 = 0.150
##        × lit 0.51 × AO 0.12 = 0.0092 ≈ 2/255。
## 1.6 米拉宽过渡带（消除 1.1 米处的硬转折），0.75 让墙脚只暗一档而不是变黑。
const CONTACT_HEIGHT: float = 1.6
const CONTACT_DARK: float = 0.75

## 低于这个高度的实心 box 不进遮挡网格（柱础、踢脚线、地面基座）。
## 依据（ch01 审核员实测）：柱础 1.3x0.28x1.3 当遮挡物时，
## 柱础自身顶点（y=0..0.28）落在它的 AABB 膨胀范围内被判为「自身」跳过，
## 但柱础侧面的采样点被 AO 压到 0.55，再叠墙脚接触阴影 0.60，
## 最终 0.483 × 0.62 × 0.55 × 0.60 ≈ 0.099 ≈ 25/255 —— 柱础读成纯黑块。
## 物理上：0.28 米高的台座挡不住什么环境光，它自己就是被地板托着的东西。
const OCCLUDER_MIN_TOP: float = 0.5

## 把章节几何里的实心 box 编成 AO 遮挡网格。
## 返回 {"cell": AO_RADIUS, "map": {Vector3i: Array[AABB]}}
static func build(geometry: Array) -> Dictionary:
	var map: Dictionary = {}
	for item: Variant in geometry:
		var g: Dictionary = item as Dictionary
		if g.is_empty() or String(g.get("k", "")) != "box":
			continue
		if not bool(g.get("body", true)):
			continue
		var size: Vector3 = g["size"]
		var pos: Vector3 = g["pos"]
		var b := AABB(pos - size * 0.5, size)
		# 整体低于 OCCLUDER_MIN_TOP 的矮台座不当遮挡物，否则柱础/踢脚线把自己压黑。
		if b.position.y + b.size.y < OCCLUDER_MIN_TOP:
			continue
		var lo: Vector3i = _cell_of(b.position)
		var hi: Vector3i = _cell_of(b.position + b.size)
		for cx: int in range(lo.x, hi.x + 1):
			for cy: int in range(lo.y, hi.y + 1):
				for cz: int in range(lo.z, hi.z + 1):
					var key := Vector3i(cx, cy, cz)
					var arr: Array = map.get(key, [])
					arr.append(b)
					map[key] = arr
	return {"cell": AO_RADIUS, "map": map}

static func _cell_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / AO_RADIUS), floori(p.y / AO_RADIUS),
		floori(p.z / AO_RADIUS))

## 采样点周围的遮挡物。cell 边长 == AO_RADIUS，所以只需看 3x3x3 邻域。
static func _near(p: Vector3, occluders: Dictionary) -> Array:
	var map: Dictionary = occluders["map"]
	var c: Vector3i = _cell_of(p)
	var out: Array = []
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var arr: Array = map.get(Vector3i(c.x + dx, c.y + dy, c.z + dz), [])
				if not arr.is_empty():
					out.append_array(arr)
	return out

## 返回 0.12~1.0 的亮度系数。occluders 为空时只算墙脚接触阴影。
static func at(p: Vector3, n: Vector3, occluders: Dictionary,
		floor_y: float = 0.0) -> float:
	var k: float = 1.0
	if not occluders.is_empty():
		var occ: float = 0.0
		for o: Variant in _near(p, occluders):
			var b: AABB = o as AABB
			# 跳过自身：box 自己的表面正好落在自己的 AABB 边界上，
			# 不跳过会让每根柱子、每张桌子把自己压成黑块。
			if b.grow(0.03).has_point(p):
				continue
			var closest: Vector3 = p.clamp(b.position, b.position + b.size)
			var d: float = p.distance_to(closest)
			if d >= AO_RADIUS:
				continue
			# 遮挡物必须落在法线的正半球才算遮挡。
			# 依据（SpotProbe 实测）：不加这一条时，柱子顶面（法线水平朝走廊）
			# 会被头顶 0.5 米处的吊顶格栅梁压到 ao=0.474（lit 0.434→实际 0.474 折损一半），
			# 会议桌桌面（法线朝上）被自己正下方的桌腿压到 0.573（桌面读成黑棕块）。
			# 物理上：朝向 -X 的面看不到 +Y 方向的梁，朝上的面也看不到脚下的桌腿。
			# 0.02 的余量用于排除与采样点共面的遮挡物（例如柱身与自己的柱础）。
			if (closest - p).dot(n) <= 0.02:
				continue
			var t: float = 1.0 - d / AO_RADIUS
			occ += t * t
		k = 1.0 - AO_STRENGTH * (1.0 - exp(-occ * 1.6))
	# 墙脚接触阴影：只给垂直面。地板朝上、天花朝下，都不该有这一项。
	if absf(n.y) < 0.55:
		var h: float = clampf((p.y - floor_y) / CONTACT_HEIGHT, 0.0, 1.0)
		# smoothstep：线性过渡会在 CONTACT_HEIGHT 处留一道可见的横线
		var s: float = h * h * (3.0 - 2.0 * h)
		k *= lerpf(CONTACT_DARK, 1.0, s)
	# 下限 0.30：审核员实测 0.12 时柱础与踢脚线叠加到 2/255（纯黑），
	# 而真实照片里最暗的接触区也有反照率可见的细节。0.30 保留暗部层次。
	return clampf(k, 0.30, 1.0)
