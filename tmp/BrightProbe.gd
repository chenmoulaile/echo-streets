extends Node

## 探针：逐章实测关键表面亮度，用于定位「太灰暗 / 过曝」。
## 只调用 LightBaker.sample，不改任何东西。
const LightBaker := preload("res://scripts/level/light_baker.gd")
const Chapters := preload("res://scripts/level/chapters.gd")

func _ready() -> void:
	for i: int in range(Chapters.count()):
		var data: ChapterData = Chapters.load_chapter(i)
		if data == null:
			continue
		print("=== %s  amb_sky=%.2f amb_ground=%.2f  lamps=%d ===" % [
			data.id, data.ambient_sky.r, data.ambient_ground.r, data.lamps.size()])
		_probe(data)
	get_tree().quit()

func _probe(data: ChapterData) -> void:
	var lamps: Array = data.lamps
	var sky: Color = data.ambient_sky
	var ground: Color = data.ambient_ground
	# 找出本章最高的灯与最低的地面，用它推算层高
	var max_lamp_y: float = 0.0
	for l: Dictionary in lamps:
		max_lamp_y = maxf(max_lamp_y, (l["pos"] as Vector3).y)
	var h: float = max_lamp_y + 0.2
	var rows: Array = []
	# 地面：灯正下方 / 两灯之间 / 远离灯
	rows.append(["floor_under_lamp", Vector3(0.0, 0.0, -18.0), Vector3.UP])
	rows.append(["floor_between", Vector3(0.0, 0.0, -15.0), Vector3.UP])
	rows.append(["floor_far", Vector3(0.0, 0.0, 0.0), Vector3.UP])
	# 天花：灯正上方外侧 / 天花中轴
	rows.append(["ceil_near_lamp", Vector3(0.0, h, -18.0), Vector3.DOWN])
	rows.append(["ceil_mid", Vector3(0.0, h, -15.0), Vector3.DOWN])
	rows.append(["ceil_axis", Vector3(0.0, h, 0.0), Vector3.DOWN])
	# 墙：齐灯高 / 腰部 / 墙脚
	rows.append(["wall_top", Vector3(-11.8, h - 0.3, 0.0), Vector3.RIGHT])
	rows.append(["wall_waist", Vector3(-11.8, 1.2, 0.0), Vector3.RIGHT])
	rows.append(["wall_foot", Vector3(-11.8, 0.15, 0.0), Vector3.RIGHT])
	for r: Array in rows:
		var p: Vector3 = r[1]
		var n: Vector3 = r[2]
		var v: Color = LightBaker.sample(p, n, lamps, sky, ground, 0.0)
		print("  %-16s %.3f  (%.2f,%.2f,%.2f)" % [r[0], v.r, v.r, v.g, v.b])
