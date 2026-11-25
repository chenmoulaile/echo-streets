## 材质描边修复：把带 1px 程序化描边的贴图边界用相邻像素覆盖，写回 assets/materials/。
## 动机（ch02 审核 P0-2「中轴竖线」的根因）：
##   triplanar 的 u = world_x * uv1_scale(0.5)，于是世界坐标 x∈[-0.01,+0.01] 这两厘米宽的
##   带恒定采样贴图的 col0（x>0 侧）与 col199（x<0 侧，wrap 后）。实测
##   CeramicFloor_White col0=(206,202,206) 而 col1=(238,234,238)，差 -30/255；
##   CeramicFloor_Gray col0=(0,0,0) 而 col1=(121,122,121)，差 -121/255 ——
##   这是一圈「1px 纯描边」，不是贴图内容。
##   这条暗带沿 Z 无限延伸且正好穿过视点，从出生点朝 -Z 看必然投影成贯穿消失点的
##   屏幕竖线（ch02_00_player 实测 x=237..241 比邻列 x=230/242 暗 15.3 灰阶，
##   近场 3~5px、远处收敛到亚像素 —— 与 2cm 带宽的透视投影完全吻合）。
##
## 为什么可以安全删：两张贴图在 col196-198 都有自己的真砖缝（White=214、Gray=89），
##   删掉 col0/col199 的描边后每块砖仍有且只有一道缝，tiling 语义不变。
##
## 只处理本章实际使用、且「描边显著暗于自身砖缝」的两张陶瓷地砖。
## 其余材质（WoodenFloor 的木纹暗边、Glass 的黑框、BrickWall 的砖缝）是内容不是伪影，
##   动它们会改变美术意图，一律不碰。
extends Node

const MAT_DIR := "res://assets/materials/"
const TARGETS: Array = ["CeramicFloor_White", "CeramicFloor_Gray"]

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
	for name: String in TARGETS:
		var path: String = MAT_DIR + name + ".png"
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			print("[%s] LOAD FAIL" % name)
			continue
		var img: Image = (tex.get_image().duplicate()) as Image
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		var before_c0 := _mean_col(img, 0)
		var before_cL := _mean_col(img, w - 1)
		var before_r0 := _mean_row(img, 0)
		var before_rL := _mean_row(img, h - 1)
		# 四边各用相邻像素覆盖（先取快照再写，避免链式覆盖）
		var col1: Array = []
		var colL1: Array = []
		for y: int in h:
			col1.append(img.get_pixel(1, y))
			colL1.append(img.get_pixel(w - 2, y))
		var row1: Array = []
		var rowL1: Array = []
		for x: int in w:
			row1.append(img.get_pixel(x, 1))
			rowL1.append(img.get_pixel(x, h - 2))
		for y: int in h:
			img.set_pixel(0, y, col1[y])
			img.set_pixel(w - 1, y, colL1[y])
		for x: int in w:
			img.set_pixel(x, 0, row1[x])
			img.set_pixel(x, h - 1, rowL1[x])
		var after_c0 := _mean_col(img, 0)
		var after_r0 := _mean_row(img, 0)
		var err: int = img.save_png(ProjectSettings.globalize_path(path))
		print("[%s] %dx%d col0 %d->%d  colL %d->%d  row0 %d->%d  rowL %d->%d  save=%d" % [
			name, w, h,
			int(before_c0.x * 255.0), int(after_c0.x * 255.0),
			int(before_cL.x * 255.0), int(after_c0.x * 255.0),
			int(before_r0.x * 255.0), int(after_r0.x * 255.0),
			int(before_rL.x * 255.0), int(after_r0.x * 255.0), err])
	get_tree().quit()
