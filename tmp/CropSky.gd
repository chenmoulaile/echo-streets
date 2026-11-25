extends Node

## 把 SkyTexture_Sunset（3860x960，地平线在 y=480）的上半天空裁出来，
## 存成 assets/textures/sky_window.png，专供"玻璃幕墙外的天空板"使用。
## 为什么需要它：幕墙天空板用 tiled=false 整面展开 0..1 UV，
## 而原图下半 50% 是亮黄沙地 —— 铺到 9.6 米高的窗上就是一条橙色墙。

const SRC := "res://assets/materials/SkyTexture_Sunset.png"
const OUT := "res://assets/textures/sky_window.png"
## 地平线：tmp/SkyRows.gd 逐行剖面实测 y=480 处 mean 从 (0.911,0.551,0.215)
## 跳到 (0.977,0.593,0.067)，y=500 起 b=0.001、r=1.000 恒定。
const HORIZON := 480
## 往下多留 40 行，让窗底带一点地平线暖调，避免天空板底边是硬切。
const KEEP_BELOW := 40

func _ready() -> void:
	var img: Image = load(SRC).get_image()
	if img == null:
		print("[cropsky] ERROR: 源图加载失败 ", SRC)
		get_tree().quit(1)
		return
	var w: int = img.get_width()
	var h: int = HORIZON + KEEP_BELOW
	# blit_rect 不做格式转换，必须先统一成 RGBA8，否则静默失败写出全黑。
	img.convert(Image.FORMAT_RGBA8)
	var band: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	band.blit_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	var err: int = band.save_png(OUT)
	print("[cropsky] %dx%d err=%d -> %s" % [w, h, err, OUT])
	# 自检：读回一次，确认不是全黑
	var check: Image = Image.load_from_file(OUT)
	var c: Color = check.get_pixel(w / 2, h / 4)
	print("[cropsky] check rgb=%.3f/%.3f/%.3f" % [c.r, c.g, c.b])
	if c.r + c.g + c.b < 0.02:
		print("[cropsky] ERROR: 输出全黑")
		get_tree().quit(1)
		return
	get_tree().quit(0)
