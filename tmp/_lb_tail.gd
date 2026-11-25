
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
