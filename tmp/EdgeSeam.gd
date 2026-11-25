extends Node
## 把陶瓷地砖的砖缝从贴图边缘滚到内部，避免砖缝正好落在世界 x=0。
##
## 完整根因链（三次定位才收敛）：
##   1. triplanar 的 u = world_x * 0.5，世界 x=0 → u=0 → 采样 col0；
##      世界 x 略小于 0 → u 为负 → fract 回绕到 col198。
##   2. 素材自带两类暗线：贴图**最外一圈** 1px 描边（col0/col199/row0/row199），
##      以及**内部真砖缝** col196-198 = rgb(214,215,214)（正常砖面 236）。
##   3. 上一轮只把外圈描边对齐了（col0 = col199），col198 仍是 214 ——
##      砖缝本身就是 25 级台阶，沿 Z 无限延伸且穿过视点 → 投影成屏幕竖线。
##   4. 正解不是抹掉砖缝（砖缝是真实内容），而是**把砖缝移出轴线**。
##
## 本轮只滚 Y 轴（上一轮误把 X/Y 都滚了，导致贴图边缘行落到中间变成横线）：
##   当前[x'][y''] = 原[x][y]，x'=(x+100)%200，y''=(y+100)%200。
##   再滚一次 Y → 得到「只滚 X」的结果：砖缝落在 col96-98（世界 x ≈ 0.97），
##   世界 x=0 落在砖面中部（236），不再有台阶。

const TARGETS: Array[String] = [
	"res://assets/materials/CeramicFloor_White.png",
	"res://assets/materials/CeramicFloor_Gray.png",
]

func _ready() -> void:
	for p: String in TARGETS:
		var abs_path: String = ProjectSettings.globalize_path(p)
		var img: Image = Image.load_from_file(abs_path)
		if img == null:
			print("[FAIL] 读不到 %s" % p)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		var rolled: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y: int in h:
			for x: int in w:
				rolled.set_pixel(x, (y + h / 2) % h, img.get_pixel(x, y))
		var err: int = rolled.save_png(abs_path)
		# 取证：世界 x=0 对应 col0，砖缝应在 col96-98
		print("[%s] %dx%d col0=%s col97=%s col1=%s save=%d"
			% [p.get_file(), w, h, _fmt(rolled.get_pixel(0, h / 2)),
				_fmt(rolled.get_pixel(97, h / 2)),
				_fmt(rolled.get_pixel(1, h / 2)), err])
	get_tree().quit(0)

func _fmt(c: Color) -> String:
	return "(%d,%d,%d)" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]
