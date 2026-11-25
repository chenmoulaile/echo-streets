## 贴图边缘探针：验证「CeramicFloor_White.png 的 col0/row0 比中心暗」是否成立。
## 动机（ch02 审核 P0-2）：走道 panel 中心 x=0，uv1_triplanar 的 u = world_x * 0.5，
##   于是整条走道恒定采样贴图第 0 列。若第 0 列比中心暗，这条暗列沿 Z 无限延伸，
##   从出生点朝 -Z 看必然投影成一条贯穿消失点的屏幕竖线（实测 x=237..241 暗 15.3 灰阶）。
## 本探针输出若干材质的边缘列/行与中心均值，判断是否为「贴图边框效应」。
extends Node

const MATS: Array = [
	"CeramicFloor_White", "CeramicFloor_Gray", "WhiteCeiling", "WhiteWall",
	"WoodenFloor", "MetalPlateWall", "WhiteWall_Dirty", "YellowWall",
]

func _ready() -> void:
	for name: String in MATS:
		var path: String = "res://assets/materials/%s.png" % name
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			print("[%s] LOAD FAIL" % name)
			continue
		var img: Image = tex.get_image()
		if img == null:
			print("[%s] NO IMAGE" % name)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		# 中心区域均值（避开边缘 10%）
		var cx0: int = int(w * 0.4)
		var cx1: int = int(w * 0.6)
		var cy0: int = int(h * 0.4)
		var cy1: int = int(h * 0.6)
		var cm := Vector3.ZERO
		var cn: int = 0
		for y: int in range(cy0, cy1):
			for x: int in range(cx0, cx1):
				var c: Color = img.get_pixel(x, y)
				cm += Vector3(c.r, c.g, c.b)
				cn += 1
		cm /= float(maxi(cn, 1))
		# 各边缘均值
		var col0 := Vector3.ZERO
		var col_last := Vector3.ZERO
		var row0 := Vector3.ZERO
		var row_last := Vector3.ZERO
		for y: int in h:
			var a: Color = img.get_pixel(0, y)
			col0 += Vector3(a.r, a.g, a.b)
			var b: Color = img.get_pixel(w - 1, y)
			col_last += Vector3(b.r, b.g, b.b)
		for x: int in w:
			var a: Color = img.get_pixel(x, 0)
			row0 += Vector3(a.r, a.g, a.b)
			var b: Color = img.get_pixel(x, h - 1)
			row_last += Vector3(b.r, b.g, b.b)
		col0 /= float(h)
		col_last /= float(h)
		row0 /= float(w)
		row_last /= float(w)
		var f := func(v: Vector3) -> String:
			return "(%d,%d,%d)" % [int(v.x * 255.0), int(v.y * 255.0), int(v.z * 255.0)]
		print("[%s] %dx%d center=%s col0=%s colL=%s row0=%s rowL=%s  dcol0=%+.1f drow0=%+.1f" % [
			name, w, h, f.call(cm), f.call(col0), f.call(col_last), f.call(row0), f.call(row_last),
			(col0.x - cm.x) * 255.0, (row0.x - cm.x) * 255.0])
	get_tree().quit()
