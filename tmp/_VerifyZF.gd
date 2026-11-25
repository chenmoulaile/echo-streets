## 一次性验证脚本（审核取证用，可删）：
##  A) 墙裙与墙共面（x=±13 同 x 值）→ Z-fighting 谁赢？
##  B) _shopfronts 的招牌朝向 `"x-" if sx<0 else "x+"` 是否把两面招牌都做成背面？
## 完全复刻 chapter_03_atrium.gd 的写法，不做任何"修正"，只看原始结果。
extends Node3D

const K := preload("res://scripts/level/chapter_kit.gd")
const B := preload("res://scripts/level/chapter_builder.gd")
const ChapterDataScript := preload("res://scripts/level/chapter_data.gd")

var cam: Camera3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.environment = e
	add_child(env)

	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 300.0
	add_child(cam)

	var d = ChapterDataScript.make("probe", "PROBE", "PROBE")
	d.mesh_step = 1.0
	d.with_ambient(Color(0.46, 0.48, 0.52), Color(0.26, 0.25, 0.24))
	# 地面 / 天花：只为给画面参照，参数照抄 ch03
	d.add(K.panel(Vector3(0, 0, 0), Vector2(26, 36), "up", "CeramicFloor_White",
		Color(0.80, 0.90, 1.00)))
	d.add(K.panel(Vector3(0, 5.2, 0), Vector2(26, 36), "down", "WhiteCeiling",
		Color(0.94, 0.95, 0.97)))
	# 左墙 x=-13 + 墙裙（chapter_03_atrium.gd:79 / :85 的写法，完全同 x 值）
	d.add(K.panel(Vector3(-13.0, 2.6, 0.0), Vector2(36, 5.2), "x+", "WhiteWall",
		Color(0.96, 0.97, 0.99)))
	d.add(K.panel(Vector3(-13.0, 0.55, 0.0), Vector2(36, 1.1), "x+", "PoolTiles",
		Color(0.86, 0.92, 1.0)))
	# 右墙 x=+13
	d.add(K.panel(Vector3(13.0, 2.6, 0.0), Vector2(36, 5.2), "x-", "WhiteWall",
		Color(0.96, 0.97, 0.99)))
	# 招牌：照抄 :155-156 的 axis 写法（左墙 sx<0 → "x-"，右墙 sx>0 → "x+"）
	d.add(K.panel(Vector3(-12.62, 2.05, 0.0), Vector2(3.2, 0.42), "x-",
		"WarningLine", Color(1, 1, 1), 1.0, false))
	d.add(K.panel(Vector3(12.62, 2.05, 0.0), Vector2(3.2, 0.42), "x+",
		"WarningLine", Color(1, 1, 1), 1.0, false))
	B.build(d, self)

	await get_tree().process_frame
	await get_tree().process_frame

	# A：站室内看左墙（x=-13）。若墙裙可见 → 蓝色底带；若被墙吃掉 → 全灰。
	cam.global_position = Vector3(-6.0, 1.6, 0.0)
	cam.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var imgA: Image = get_viewport().get_texture().get_image()
	imgA.save_png("res://tmp/_zf_left.png")
	print("[zf] LEFT wall  y=240 x=240 -> ", imgA.get_pixel(240, 240),
		"   y=190 x=240 -> ", imgA.get_pixel(240, 190))

	# B：站室内看右墙（x=+13），招牌在 y=2.05、z=0。
	cam.global_position = Vector3(6.0, 1.6, 0.0)
	cam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var imgB: Image = get_viewport().get_texture().get_image()
	imgB.save_png("res://tmp/_zf_right.png")
	# 招牌中心在画面上半部；扫一列找最亮的黄
	var best := 0.0
	var besty := -1
	for y: int in range(60, 140):
		var c: Color = imgB.get_pixel(240, y)
		var l: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		if l > best:
			best = l
			besty = y
	print("[zf] RIGHT wall best luma in y60..140 = %.3f at y=%d (招牌应在此)" % [best, besty])
	print("[zf] saved _zf_left.png / _zf_right.png")
	get_tree().quit()
