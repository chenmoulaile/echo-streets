## 贴图边框宽度探针：确认 CeramicFloor_White / CeramicFloor_Gray 的边缘异常占几像素。
## 动机：EdgeProbe 实测两者四边均值完全一致且显著偏离中心
##   （White col0=(206,202,206) vs center (236,236,236) 差 -30；
##     Gray col0=(0,0,0) vs center (125,126,125) 差 -126），
##   说明贴图带一圈「程序化描边」。若只有 1px，可用第 1 行/列覆盖修掉；
##   若有多像素，需要判断是否是有意的地砖缝（Gray 的黑边很可能是缝）。
extends Node

const NAMES: Array = ["CeramicFloor_White", "CeramicFloor_Gray"]

func _ready() -> void:
	for name: String in NAMES:
		var tex: Texture2D = load("res://assets/materials/%s.png" % name) as Texture2D
		var img: Image = tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		print("=== %s %dx%d ===" % [name, w, h])
		# 逐列均值（前 8 列 + 中间 1 列 + 后 8 列）
		var probes: Array = []
		for i: int in 8:
			probes.append(i)
		probes.append(int(w / 2))
		for i: int in 8:
			probes.append(w - 8 + i)
		for x: int in probes:
			var acc := Vector3.ZERO
			for y: int in h:
				var c: Color = img.get_pixel(x, y)
				acc += Vector3(c.r, c.g, c.b)
			acc /= float(h)
			print("  col %3d -> (%3d,%3d,%3d)" % [x, int(acc.x * 255.0), int(acc.y * 255.0), int(acc.z * 255.0)])
		# 逐行均值
		var rp: Array = []
		for i: int in 8:
			rp.append(i)
		rp.append(int(h / 2))
		for i: int in 8:
			rp.append(h - 8 + i)
		for y: int in rp:
			var acc := Vector3.ZERO
			for x: int in w:
				var c: Color = img.get_pixel(x, y)
				acc += Vector3(c.r, c.g, c.b)
			acc /= float(w)
			print("  row %3d -> (%3d,%3d,%3d)" % [y, int(acc.x * 255.0), int(acc.y * 255.0), int(acc.z * 255.0)])
	get_tree().quit()
