## 生成 Glass_Pane.png：把 Glass.png 的 alpha 通道整体提亮，供需要"看得见的玻璃"用。
## 动机（ch02 审核 P0-3）：
##   chapter_builder 的 alpha 是「与贴图 alpha 相乘」。Glass.png 的 alpha p50 只有 26/255
##   （0.102），所以章节传 0.42 时有效 alpha = 0.42 × 0.102 = 0.043 —— 与背后白墙
##   rgb(196,197,196) 混合后理论 B-R 只有 3（实测 0~11，完全吻合），玻璃读不出玻璃。
##   章节参数封顶 1.0，有效 alpha 数学上不可能超过 0.102，这是硬约束。
##
## 为什么不直接改 Glass.png：ch01 幕墙 / ch04 玻璃栏板都依赖「几乎全透」的观感
##   （ch01 审核明确把「04_left 橙色像素 57.65%」列为通过项）。改源图会把三章一起改坏。
##   所以另存一张高 alpha 版本，只给需要实心感玻璃的章节用。
##
## 提升倍数 4.0：p50 26 → 104（0.408）。配合章节 alpha 0.72 得有效 0.294，
##   与背后白墙混合后 B-R ≈ 0.29 × (255-196) ≈ 17，叠加青色 tint 后可读出玻璃膜。
## RGB 通道保持原样（Glass.png 中心是 rgb(200,242,255) 冷青，正是想要的色相）。
extends Node

const SRC := "res://assets/materials/Glass.png"
const DST := "res://assets/materials/Glass_Pane.png"
const GAIN := 4.0

func _ready() -> void:
	var tex: Texture2D = load(SRC) as Texture2D
	if tex == null:
		print("[GlassPane] LOAD FAIL")
		get_tree().quit()
		return
	var img: Image = (tex.get_image().duplicate()) as Image
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum_before: float = 0.0
	var sum_after: float = 0.0
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			sum_before += c.a
			var na: float = clampf(c.a * GAIN, 0.0, 1.0)
			sum_after += na
			img.set_pixel(x, y, Color(c.r, c.g, c.b, na))
	var n: float = float(w * h)
	var err: int = img.save_png(ProjectSettings.globalize_path(DST))
	print("[GlassPane] %dx%d alpha mean %.1f -> %.1f (x%.1f)  save=%d" % [
		w, h, sum_before / n * 255.0, sum_after / n * 255.0, GAIN, err])
	get_tree().quit()
