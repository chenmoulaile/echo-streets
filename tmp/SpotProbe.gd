extends Node

## 定点光照探针：把 LightBaker.sample 在指定世界坐标的返回值打出来。
## 用途：截帧只能看到「渲染后」的颜色，分不清是 lit 低还是 tint 低还是 AO 压的。
## 这个探针把三个乘数拆开打印，才能定位到底哪一项在吃亮度。

const CH01 := preload("res://scripts/level/chapter_01_lobby.gd")
const LB := preload("res://scripts/level/light_baker.gd")
const AO := preload("res://scripts/level/light_ao.gd")

func _ready() -> void:
	# 注意：CH01 是 const 脚本常量，不是 Object 实例，不能 CH01.call("build")。
	# 静态函数直接点号调用（light_baker.gd 里的 LightAO.at(...) 同理）。
	var d: ChapterData = CH01.build()
	var occ: Dictionary = LB.build_occluders(d.geometry)
	print("=== lamps=", d.lamps.size(), " occ_cells=", (occ["map"] as Dictionary).size())
	# 柱面（朝 -X，即朝向走廊中心）：柱子在 x=±6.4，柱宽 1.1 → 内侧面 x=5.85
	_probe("col_inner_y0.4", Vector3(5.85, 0.4, -18.0), Vector3.LEFT, d, occ)
	_probe("col_inner_y1.8", Vector3(5.85, 1.8, -18.0), Vector3.LEFT, d, occ)
	_probe("col_inner_y3.0", Vector3(5.85, 3.0, -18.0), Vector3.LEFT, d, occ)
	_probe("col_front_y1.8", Vector3(6.4, 1.8, -17.45), Vector3.FORWARD, d, occ)
	# 右墙内表面 x=+11
	_probe("wall_right_y1.8", Vector3(10.95, 1.8, 0.0), Vector3.LEFT, d, occ)
	_probe("wall_back_y1.8", Vector3(0.0, 1.8, -22.95), Vector3.BACK, d, occ)
	# 地板 / 天花
	_probe("floor_mid", Vector3(0.0, 0.0, 0.0), Vector3.UP, d, occ)
	_probe("ceil_mid", Vector3(0.0, 3.6, 0.0), Vector3.DOWN, d, occ)
	get_tree().quit(0)

func _probe(tag: String, p: Vector3, n: Vector3, d: ChapterData,
		occ: Dictionary) -> void:
	var lit: Color = LB.sample(p, n, d.lamps, d.ambient_sky, d.ambient_ground, 0.0, occ)
	var ao: float = AO.at(p, n, occ, 0.0)
	var no_ao: Color = LB.sample(p, n, d.lamps, d.ambient_sky, d.ambient_ground, 0.0, {})
	print("[probe] %-16s lit=%.3f ao=%.3f lit_noao=%.3f" % [tag, lit.r, ao, no_ao.r])
