## 网格细分与顶点色写入（light_baker 的几何生成部分）
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么拆出来: light_baker.gd 加入太阳方向光后涨到 412 行，
##   超出 PDF 硬红线「单文件 ≤300 行」。这里只保留"怎么把一个面切成网格、
##   逐顶点采样光照、写 COLOR 通道"的纯几何逻辑，光照数学仍在 light_baker。
##   拆分后 light_baker 只剩常量 + sample/_direct + 薄转发。
## 依赖方向: mesh_builder → light_baker（单向，light_baker 用 preload 转发）
##   GDScript 的 preload 循环会报错，所以本文件 preload light_baker，
##   light_baker 里用 const 懒加载转发 —— 用 preload 会形成环。
extends RefCounted

const LightBaker := preload("res://scripts/level/light_baker.gd")

## 轴名 → (u 轴, v 轴, 法线)。u/v 决定平面展开方向，法线用于光照与绕序。
static func axes(axis: String) -> Array:
	match axis:
		"up":
			return [Vector3.RIGHT, Vector3.BACK, Vector3.UP]
		"down":
			return [Vector3.RIGHT, Vector3.BACK, Vector3.DOWN]
		"z+":
			return [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		"z-":
			return [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
		"x+":
			return [Vector3.BACK, Vector3.UP, Vector3.RIGHT]
		_:
			return [Vector3.BACK, Vector3.UP, Vector3.LEFT]

## 细分平面网格：逐顶点烘焙光照写进 COLOR 通道。
## center 是平面中心；size 是平面两轴尺寸；step 是目标网格边长（米）。
## tiled=true 走世界坐标平铺（墙地砖缝对齐），false 走 0..1 整面展开
## （天空板/屏幕这类有构图的大图）。
## 返回 ArrayMesh（已带 ARRAY_COLOR），调用方负责建 MeshInstance3D 与材质。
static func build_panel(center: Vector3, size: Vector2, axis: String,
		lamps: Array, tint: Color, step: float = 1.0,
		amb_sky: Color = LightBaker.AMB_SKY,
		amb_ground: Color = LightBaker.AMB_GROUND,
		tiled: bool = true, emissive: bool = false,
		occluders: Dictionary = {}) -> ArrayMesh:
	var a: Array = axes(axis)
	var u_axis: Vector3 = a[0]
	var v_axis: Vector3 = a[1]
	var n: Vector3 = a[2]
	var nu: int = maxi(int(round(size.x / maxf(step, 0.1))), 1)
	var nv: int = maxi(int(round(size.y / maxf(step, 0.1))), 1)
	var cols: int = nu + 1
	var rows: int = nv + 1

	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	verts.resize(cols * rows)
	normals.resize(cols * rows)
	colors.resize(cols * rows)
	uvs.resize(cols * rows)

	var half_u: float = size.x * 0.5
	var half_v: float = size.y * 0.5
	var idx: int = 0
	for j: int in rows:
		var fv: float = -half_v + size.y * float(j) / float(nv)
		for i: int in cols:
			var fu: float = -half_u + size.x * float(i) / float(nu)
			var p: Vector3 = center + u_axis * fu + v_axis * fv
			verts[idx] = p
			normals[idx] = n
			# 顶点色 = tint × 烘焙光照。tint 承载「这块墙偏冷/偏暖」的设计意图。
			# emissive 面（灯具发光面/灯箱/亮屏）直接用 tint，不乘光照 ——
			# 发光体本身亮度不该被周围环境照度决定，否则灯会比天花还暗。
			if emissive:
				colors[idx] = Color(tint.r, tint.g, tint.b, 1.0)
			else:
				var lit: Color = LightBaker.sample(p, n, lamps, amb_sky,
					amb_ground, 0.0, occluders)
				colors[idx] = Color(tint.r * lit.r, tint.g * lit.g, tint.b * lit.b, 1.0)
			# UV：tiled 走世界米数（配合 uv1_scale 0.5 → 1 米 = 半张贴图，砖缝对齐）；
			# 非 tiled 走 0..1 整面展开，给天空板/屏幕这类有构图的大图。
			# emissive 面例外：锁定到贴图正中一小块。
			#   依据（实测 tmp/Crop 逐行采样 WhiteCeiling_MetalEdge）：
			#   第 0 行 rgb(145,169,179) 蓝灰边框、第 1 行 rgb(1,1,1) 纯黑线、
			#   第 2 行起 rgb(230) 内芯。灯位 z 全是 6 的倍数 → v = z*0.5 恒为整数，
			#   NEAREST 采样正好压在第 0 行，于是 21 盏灯全部渲染成蓝灰边框色。
			#   取中心 0.5 最稳，不随灯位/尺寸漂移。
			if emissive:
				uvs[idx] = Vector2(0.5, 0.5)
			elif tiled:
				uvs[idx] = Vector2(p.dot(u_axis), p.dot(v_axis)) * 0.5
			else:
				# 非 tiled 的 v 必须翻转（ch01 审核 P0，天空板上下颠倒）：
				#   axes("x+") 的 v 轴是 +Y（向上），而贴图 v=0 在顶行。
				#   不翻转时贴图顶行被映射到板底 —— sky_window.png 本身是
				#   「上暗紫、下亮黄」的正确晚霞，渲染出来却成了「上亮橙、下暗紫」，
				#   实测 04_left.png x=250 屏幕 y=70 (210,126,74) → y=156 (117,64,74)。
				uvs[idx] = Vector2(float(i) / float(nu), 1.0 - float(j) / float(nv))
			idx += 1

	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(nu * nv * 6)
	var k: int = 0
	for j: int in nv:
		for i: int in nu:
			var v00: int = j * cols + i
			var v10: int = v00 + 1
			var v01: int = v00 + cols
			var v11: int = v01 + 1
			# 绕序：Godot 的正面是顺时针，可见条件是「三角形几何法线 = -顶点法线」。
			# 实测（tmp/wind_runner.tscn）：A 序 (v00,v10,v01) 亮度 0.000 被剔除，
			# B 序 (v00,v01,v10) 亮度 0.680 可见。A 序的几何法线 = +(u×v)，
			# B 序 = -(u×v)，所以 u×v 与 n 反向时必须走 A 序，同向时走 B 序。
			# 这个条件写反会让地板/天花板整片消失（只看到墙和柱子）。
			var flip: bool = (u_axis.cross(v_axis)).dot(n) < 0.0
			if flip:
				indices[k] = v00
				indices[k + 1] = v10
				indices[k + 2] = v01
				indices[k + 3] = v10
				indices[k + 4] = v11
				indices[k + 5] = v01
			else:
				indices[k] = v00
				indices[k + 1] = v01
				indices[k + 2] = v10
				indices[k + 3] = v10
				indices[k + 4] = v01
				indices[k + 5] = v11
			k += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## 实心方块网格：六个面各自细分成 panel 再合并。
## 只给一个中心色会失去明暗过渡，柱子会像贴纸；逐面烘焙才有体积感。
static func build_box(center: Vector3, size: Vector3, lamps: Array, tint: Color,
		step: float = 1.0, amb_sky: Color = LightBaker.AMB_SKY,
		amb_ground: Color = LightBaker.AMB_GROUND,
		occluders: Dictionary = {}) -> ArrayMesh:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	# 面定义：[轴, 中心偏移, 平面尺寸(u,v)]
	var faces: Array = [
		["up", Vector3(0.0, hy, 0.0), Vector2(size.x, size.z)],
		["down", Vector3(0.0, -hy, 0.0), Vector2(size.x, size.z)],
		["z+", Vector3(0.0, 0.0, hz), Vector2(size.x, size.y)],
		["z-", Vector3(0.0, 0.0, -hz), Vector2(size.x, size.y)],
		["x+", Vector3(hx, 0.0, 0.0), Vector2(size.z, size.y)],
		["x-", Vector3(-hx, 0.0, 0.0), Vector2(size.z, size.y)],
	]
	for f: Array in faces:
		var axis: String = f[0]
		var off: Vector3 = f[1]
		var psize: Vector2 = f[2]
		var a: Array = axes(axis)
		var u_axis: Vector3 = a[0]
		var v_axis: Vector3 = a[1]
		var n: Vector3 = a[2]
		var fc: Vector3 = center + off
		var nu: int = maxi(int(round(psize.x / maxf(step, 0.1))), 1)
		var nv: int = maxi(int(round(psize.y / maxf(step, 0.1))), 1)
		var base: int = verts.size()
		for j: int in nv + 1:
			var fv: float = -psize.y * 0.5 + psize.y * float(j) / float(nv)
			for i: int in nu + 1:
				var fu: float = -psize.x * 0.5 + psize.x * float(i) / float(nu)
				var p: Vector3 = fc + u_axis * fu + v_axis * fv
				verts.append(p)
				normals.append(n)
				var lit: Color = LightBaker.sample(p, n, lamps, amb_sky,
					amb_ground, 0.0, occluders)
				colors.append(Color(tint.r * lit.r, tint.g * lit.g,
					tint.b * lit.b, 1.0))
				uvs.append(Vector2(p.dot(u_axis), p.dot(v_axis)) * 0.5)
		var flip: bool = (u_axis.cross(v_axis)).dot(n) < 0.0
		var cols: int = nu + 1
		for j: int in nv:
			for i: int in nu:
				var v00: int = base + j * cols + i
				var v10: int = v00 + 1
				var v01: int = v00 + cols
				var v11: int = v01 + 1
				# 与 build_panel 同一套绕序规则：正面 = 顺时针 = 几何法线与顶点法线相反
				if flip:
					indices.append_array([v00, v10, v01, v10, v11, v01])
				else:
					indices.append_array([v00, v01, v10, v10, v01, v11])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
