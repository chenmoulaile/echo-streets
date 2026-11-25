## 诊断：打印 SkyTexture_Sunset 逐行均值与标准差，定位真实地平线。
## 上一版用"相邻行色差最大"判定，得到 480（50%），但目视地平线在 35% 附近 —— 需要看数据。
extends Node

const SRC := "res://assets/materials/SkyTexture_Sunset.png"

func _ready() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img.is_compressed():
		img.decompress()
	var h: int = img.get_height()
	var w: int = img.get_width()
	print("[rows] %dx%d fmt=%d" % [w, h, img.get_format()])
	var y: int = 0
	while y < h:
		var st := _stats(img, y)
		print("y=%4d  mean=%.3f %.3f %.3f  sd=%.4f  lum=%.3f" % [
			y, st[0], st[1], st[2], st[3], st[4]])
		y += 20
	get_tree().quit()

## 返回 [r, g, b, 标准差(亮度), 亮度]
func _stats(img: Image, y: int) -> Array:
	var w: int = img.get_width()
	var n: int = 0
	var sr: float = 0.0
	var sg: float = 0.0
	var sb: float = 0.0
	for x: int in range(0, w, 8):
		var c := img.get_pixel(x, y)
		sr += c.r
		sg += c.g
		sb += c.b
		n += 1
	sr /= n
	sg /= n
	sb /= n
	var var_sum: float = 0.0
	for x: int in range(0, w, 8):
		var c := img.get_pixel(x, y)
		var l: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
		var m: float = 0.299 * sr + 0.587 * sg + 0.114 * sb
		var_sum += (l - m) * (l - m)
	return [sr, sg, sb, sqrt(var_sum / n), 0.299 * sr + 0.587 * sg + 0.114 * sb]
