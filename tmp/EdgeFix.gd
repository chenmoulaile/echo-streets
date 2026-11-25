## 材质描边扫描：找出「第 0 列/行与第 1 列/行差异显著」的贴图。
## 动机（ch02 审核 P0-2 的中轴竖线）：triplanar 的 u = world_x * 0.5，
##   于是世界坐标 x=0 这条线恒定采样贴图第 0 列。若第 0 列带一圈程序化描边，
##   这条描边沿 Z 无限延伸，从出生点朝 -Z 看必然投影成贯穿消失点的屏幕竖线
##   （实测 ch02_00_player x=237..241 比邻列暗 15.3 灰阶）。
## 判据：|col0 - col1| > 8 且 col1/col2/col3 三者互差 < 4（说明 col0 是独立描边，
##   不是贴图内容的自然渐变）。同理判 row0。第 199 列/行一并检查。
## 输出：命中清单 + 修复副本写到 tmp/fixed_mats/（不直接覆盖源文件）。
extends Node

const MAT_DIR := "res://assets/materials/"
const OUT_DIR := "res://tmp/fixed_mats/"

func _mean_col(img: Image, x: int) -> Vector3:
	var acc := Vector3.ZERO
	var h: int = img.get_height()
	for y: int in h:
		var c: Color = img.get_pixel(x, y)
		acc += Vector3(c.r, c.g, c.b)
	return acc / float(maxi(h, 1))

func _mean_row(img: Image, y: int) -> Vector3:
	var acc := Vector3.ZERO
	var w: int = img.get_width()
	for x: int in w:
		var c: Color = img.get_pixel(x, y)
		acc += Vector3(c.r, c.g, c.b)
	return acc / float(maxi(w, 1))

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var files: PackedStringArray = DirAccess.get_files_at(MAT_DIR)
	var hits: int = 0
	var total: int = 0
	for f: String in files:
		if not f.ends_with(".png"):
			continue
		total += 1
		var name: String = f.get_basename()
		var tex: Texture2D = load(MAT_DIR + f) as Texture2D
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		if w < 8 or h < 8:
			continue
		var c0 := _mean_col(img, 0)
		var c1 := _mean_col(img, 1)
		var c2 := _mean_col(img, 2)
		var c3 := _mean_col(img, 3)
		var cL := _mean_col(img, w - 1)
		var cL1 := _mean_col(img, w - 2)
		var r0 := _mean_row(img, 0)
		var r1 := _mean_row(img, 1)
		var r2 := _mean_row(img, 2)
		var r3 := _mean_row(img, 3)
		var rL := _mean_row(img, h - 1)
		var rL1 := _mean_row(img, h - 2)
		var inner_x: float = maxf(maxf((c1 - c2).length(), (c2 - c3).length()), (c1 - c3).length())
		var inner_y: float = maxf(maxf((r1 - r2).length(), (r2 - r3).length()), (r1 - r3).length())
		var edge_x: float = maxf((c0 - c1).length(), (cL - cL1).length())
		var edge_y: float = maxf((r0 - r1).length(), (rL - rL1).length())
		# 换算成 0~255 灰阶差便于判断
		var d_x: float = edge_x * 255.0
		var d_y: float = edge_y * 255.0
		var in_x: float = inner_x * 255.0
		var in_y: float = inner_y * 255.0
		var bad_x: bool = d_x > 8.0 and in_x < 4.0
		var bad_y: bool = d_y > 8.0 and in_y < 4.0
		if bad_x or bad_y:
			hits += 1
			print("[HIT] %-28s %dx%d  edgeX=%+.1f innerX=%.1f  edgeY=%+.1f innerY=%.1f" % [
				name, w, h, d_x, in_x, d_y, in_y])
			# 用第 1 列/行覆盖第 0 列/行，用倒数第 2 列/行覆盖最后列/行
			if bad_x:
				for y: int in h:
					img.set_pixel(0, y, img.get_pixel(1, y))
					img.set_pixel(w - 1, y, img.get_pixel(w - 2, y))
			if bad_y:
				for x: int in w:
					img.set_pixel(x, 0, img.get_pixel(x, 1))
					img.set_pixel(x, h - 1, img.get_pixel(x, h - 2))
			var err: int = img.save_png(OUT_DIR + name + ".png")
			print("        -> saved %s err=%d" % [OUT_DIR + name + ".png", err])
	print("[SUMMARY] scanned=%d hits=%d" % [total, hits])
	get_tree().quit()
