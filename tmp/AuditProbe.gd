## 审核探针：对 chapter_02 做几何 AABB 重叠、烘焙亮度极值、UV 密度核算。
## 只读，不改任何项目源码。
extends Node

const LightBaker := preload("res://scripts/level/light_baker.gd")
const K := preload("res://scripts/level/chapter_kit.gd")

func _ready() -> void:
	var data: ChapterData = load("res://scripts/level/chapter_02_office.gd").call("build")
	var lamps: Array = data.lamps
	var sky: Color = data.ambient_sky
	var ground: Color = data.ambient_ground
	print("[audit] geo=%d lamps=%d amb_sky=%s amb_ground=%s" % [
		data.geometry.size(), lamps.size(), str(sky), str(ground)])

	_geom_overlap(data)
	_brightness(data, lamps, sky, ground)
	_uv_density(data)
	_material_names(data)
	get_tree().quit()

## ---------- 1. 几何 AABB 重叠（同材质/近距穿透） ----------
func _aabb(g: Dictionary) -> AABB:
	var p: Vector3 = g["pos"]
	if String(g["k"]) == "box":
		var s: Vector3 = g["size"]
		return AABB(p - s * 0.5, s)
	var size: Vector2 = g["size"]
	var axis: String = g["axis"]
	var s2: Vector3 = Vector3(size.x, 0.0, size.y) if (axis == "up" or axis == "down") else (
		Vector3(size.x, size.y, 0.0) if axis.begins_with("z") else Vector3(0.0, size.y, size.x))
	return AABB(p - s2 * 0.5, s2)

func _geom_overlap(data: ChapterData) -> void:
	var items: Array = []
	for i: int in data.geometry.size():
		var g: Dictionary = data.geometry[i]
		items.append({"i": i, "g": g, "a": _aabb(g)})
	print("[audit] --- AABB 重叠（体积交集 > 0.0005 m^3，排除地面/天花平面） ---")
	var n: int = 0
	for i: int in items.size():
		for j: int in range(i + 1, items.size()):
			var A: AABB = items[i]["a"]
			var B: AABB = items[j]["a"]
			if not A.intersects(B):
				continue
			var inter: AABB = A.intersection(B)
			var v: float = inter.size.x * inter.size.y * inter.size.z
			if v <= 0.0005:
				continue
			var ga: Dictionary = items[i]["g"]
			var gb: Dictionary = items[j]["g"]
			# 平面与平面相交体积恒为 0，这里只会抓到 box-box 或 panel 的碰撞体厚度
			print("  OVERLAP vol=%.4f  #%d(%s %s @%s size=%s)  <->  #%d(%s %s @%s size=%s)" % [
				v, i, ga["k"], ga["mat"], str(ga["pos"]), str(ga.get("size", Vector2.ZERO)),
				j, gb["k"], gb["mat"], str(gb["pos"]), str(gb.get("size", Vector2.ZERO))])
			n += 1
			if n > 40:
				print("  ... 截断")
				return
	print("  合计 %d 处" % n)

## ---------- 2. 烘焙亮度极值 ----------
func _brightness(data: ChapterData, lamps: Array, sky: Color, ground: Color) -> void:
	# 全场景按 0.25 米网格采样每个面的顶点位置，统计削顶/死黑
	var vals: Array = []   # [lum, pos, mat]
	var clips: int = 0
	var deads: int = 0
	var total: int = 0
	for g: Dictionary in data.geometry:
		var a: AABB = _aabb(g)
		var tint: Color = g["tint"]
		var is_box: bool = String(g["k"]) == "box"
		var step: float = 0.5 if is_box else float(g.get("step", 1.0))
		var faces: Array = []
		if is_box:
			faces = [["up", a.get_center() + Vector3(0, a.size.y * 0.5, 0)],
				["down", a.get_center() - Vector3(0, a.size.y * 0.5, 0)],
				["z+", a.get_center() + Vector3(0, 0, a.size.z * 0.5)],
				["z-", a.get_center() - Vector3(0, 0, a.size.z * 0.5)],
				["x+", a.get_center() + Vector3(a.size.x * 0.5, 0, 0)],
				["x-", a.get_center() - Vector3(a.size.x * 0.5, 0, 0)]]
		else:
			faces = [[String(g["axis"]), a.get_center()]]
		for f: Array in faces:
			var axis: String = f[0]
			var fc: Vector3 = f[1]
			var ax: Array = LightBaker.axes(axis)
			var u: Vector3 = ax[0]
			var v: Vector3 = ax[1]
			var n: Vector3 = ax[2]
			var su: float = a.size.x if (axis == "up" or axis == "down" or axis.begins_with("z")) else a.size.z
			var sv: float = a.size.z if (axis == "up" or axis == "down") else a.size.y
			if not is_box:
				var s2: Vector2 = g["size"]
				su = s2.x
				sv = s2.y
			var nu: int = maxi(int(su / step), 1)
			var nv: int = maxi(int(sv / step), 1)
			for jj: int in nv + 1:
				for ii: int in nu + 1:
					var p: Vector3 = fc + u * (-su * 0.5 + su * float(ii) / float(nu)) \
						+ v * (-sv * 0.5 + sv * float(jj) / float(nv))
					var lit: Color = LightBaker.sample(p, n, lamps, sky, ground)
					var c: Color = Color(tint.r * lit.r, tint.g * lit.g, tint.b * lit.b)
					var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
					total += 1
					if l >= 1.0:
						clips += 1
					if l < 0.15:
						deads += 1
					vals.append([l, p, String(g["mat"]), axis])
	print("[audit] 采样点 %d  削顶(>=1.0)=%d (%.2f%%)  死黑(<0.15)=%d (%.2f%%)" % [
		total, clips, 100.0 * clips / total, deads, 100.0 * deads / total])
	vals.sort_custom(func(x, y): return x[0] < y[0])
	print("[audit] --- 最暗 12 点 ---")
	for i: int in mini(12, vals.size()):
		print("  lum=%.3f pos=(%.2f,%.2f,%.2f) mat=%s axis=%s" % [
			vals[i][0], vals[i][1].x, vals[i][1].y, vals[i][1].z, vals[i][2], vals[i][3]])
	print("[audit] --- 最亮 12 点 ---")
	for i: int in range(maxi(vals.size() - 12, 0), vals.size()):
		print("  lum=%.3f pos=(%.2f,%.2f,%.2f) mat=%s axis=%s" % [
			vals[i][0], vals[i][1].x, vals[i][1].y, vals[i][1].z, vals[i][2], vals[i][3]])

	# 定点采样表
	var pts: Array = [
		["floor wood under lamp x=-7", Vector3(-7.0, 0.0, 0.0), Vector3.UP],
		["floor wood between lamps", Vector3(-7.0, 0.0, 3.0), Vector3.UP],
		["floor wood far corner", Vector3(-11.5, 0.0, 19.5), Vector3.UP],
		["corridor ceramic center", Vector3(0.0, 0.012, 0.0), Vector3.UP],
		["corridor ceramic under lamp", Vector3(0.0, 0.012, 6.0), Vector3.UP],
		["ceiling under lamp panel", Vector3(0.0, 3.115, 6.0), Vector3.DOWN],
		["ceiling between lamps", Vector3(0.0, 3.2, 3.0), Vector3.DOWN],
		["ceiling far corner", Vector3(-11.5, 3.2, 19.5), Vector3.DOWN],
		["wall left mid", Vector3(-12.0, 1.6, 0.0), Vector3.RIGHT],
		["wall left top", Vector3(-12.0, 3.0, 0.0), Vector3.RIGHT],
		["wall left bottom", Vector3(-12.0, 0.1, 0.0), Vector3.RIGHT],
		["wall yellow far mid", Vector3(0.0, 1.6, -20.0), Vector3.BACK],
		["wall yellow far bottom", Vector3(0.0, 0.15, -20.0), Vector3.BACK],
		["wall near white mid", Vector3(0.0, 1.6, 20.0), Vector3.FORWARD],
		["desk top", Vector3(-8.6, 0.775, 2.0), Vector3.UP],
		["desk underside", Vector3(-8.6, 0.715, 2.0), Vector3.DOWN],
		["monitor front", Vector3(-8.6, 1.02, 1.795), Vector3.BACK],
		["partition front", Vector3(-8.6, 0.98, 2.425), Vector3.BACK],
		["meeting carpet room2 center", Vector3(8.6, 0.021, 1.5), Vector3.UP],
		["meeting carpet room2 corner", Vector3(6.1, 0.021, -0.8), Vector3.UP],
		["meeting carpet room1 corner", Vector3(11.3, 0.021, -10.8), Vector3.UP],
		["meeting table top room2", Vector3(8.6, 0.77, 1.5), Vector3.UP],
		["meeting table top room1", Vector3(8.6, 0.77, -8.5), Vector3.UP],
		["glass long wall inner", Vector3(5.6, 1.6, 1.5), Vector3.LEFT],
		["glass short wall room1 z0", Vector3(8.7, 1.6, -11.0), Vector3.BACK],
		["room2 ceiling", Vector3(8.6, 3.2, 1.5), Vector3.DOWN],
		["room1 ceiling", Vector3(8.6, 3.2, -8.5), Vector3.DOWN],
		["room1 ceiling corner", Vector3(6.1, 3.2, -10.8), Vector3.DOWN],
	]
	print("[audit] --- 定点烘焙亮度（含 tint 后） ---")
	for r: Array in pts:
		var p: Vector3 = r[1]
		var n: Vector3 = r[2]
		var lit: Color = LightBaker.sample(p, n, lamps, sky, ground)
		var l: float = 0.2126 * lit.r + 0.7152 * lit.g + 0.0722 * lit.b
		print("  %-32s lum=%.3f  rgb=(%.3f,%.3f,%.3f)" % [r[0], l, lit.r, lit.g, lit.b])

## ---------- 3. UV 密度 ----------
func _uv_density(data: ChapterData) -> void:
	print("[audit] --- UV 密度（uv1_scale=0.5 → UV 增量 0.5/米） ---")
	for g: Dictionary in data.geometry:
		var m: String = g["mat"]
		if m in ["WoodenFloor", "CeramicFloor_White", "survival__Backroom__CarpetFloor",
				"WhiteCeiling", "YellowWall", "MetalPlateWall", "WhiteCeiling_MetalEdge"]:
			var s: Variant = g.get("size")
			print("  %s tiled=%s step=%s size=%s pos=%s" % [
				m, str(g.get("tiled", true)), str(g.get("step", 1.0)), str(s), str(g["pos"])])

## ---------- 4. 材质名存在性 ----------
func _material_names(data: ChapterData) -> void:
	print("[audit] --- 材质名解析 ---")
	var seen: Dictionary = {}
	for g: Dictionary in data.geometry:
		var m: String = g["mat"]
		if seen.has(m):
			continue
		seen[m] = true
		var path: String = "res://assets/materials/" + m + ".png"
		print("  %-34s exists=%s" % [m, str(ResourceLoader.exists(path))])
