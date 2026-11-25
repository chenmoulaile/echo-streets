# 受控视觉验证：每个着色器在原生宿主节点上单独并排渲染，抓帧对比。
# 用法：godot --path D:\mygame --rendering-driver opengl3 --resolution 1280x720 --script res://tmp/vcheck2.gd
extends SceneTree

const OUT := "res://tmp/out"

var _f := 0
var _m: Dictionary = {}


func _tex(w: int, h: int, fn: Callable) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			img.set_pixel(x, y, fn.call(x, y))
	return ImageTexture.create_from_image(img)


func _zombie() -> ImageTexture:
	return _tex(16, 16, func(x, y):
		if y >= 6 and y < 16 and x >= 5 and x < 11:
			return Color(0.35, 0.45, 0.30, 1.0)
		if y >= 2 and y < 7 and x >= 5 and x < 11:
			return Color(0.62, 0.55, 0.42, 1.0)
		return Color(0, 0, 0, 0))


func _blob() -> ImageTexture:
	# 圆形血斑：中心亮边缘暗，带硬边透明
	return _tex(16, 16, func(x, y):
		var d := Vector2(x - 7.5, y - 7.5).length()
		if d > 7.0:
			return Color(0, 0, 0, 0)
		var k := 1.0 - d / 7.0
		return Color(0.55 + 0.45 * k, 0.30 + 0.30 * k, 0.30 + 0.30 * k, 1.0))


func _panel(parent: Node, pos: Vector2, label: String, tex: Texture2D, shader_path: String, params: Dictionary) -> void:
	var holder := Control.new()
	holder.position = pos
	holder.size = Vector2(240, 300)
	parent.add_child(holder)

	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = Vector2(0, 0)
	tr.size = Vector2(240, 240)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	tr.material = mat
	holder.add_child(tr)
	_m[label] = mat

	var lb := Label.new()
	lb.text = label
	lb.position = Vector2(0, 246)
	holder.add_child(lb)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var z := _zombie()
	var b := _blob()
	var checker := _tex(32, 32, func(x, y):
		return Color(0.75, 0.75, 0.75) if ((x / 4) + (y / 4)) % 2 == 0 else Color(0.35, 0.35, 0.35))

	# 丧尸受击闪白：0 / 0.35 / 1.0 三档
	_panel(root, Vector2(20, 20), "hit_flash=0.0", z, "res://shaders/zombie_hit_flash.gdshader", {"flash_amount": 0.0})
	_panel(root, Vector2(270, 20), "hit_flash=0.35", z, "res://shaders/zombie_hit_flash.gdshader", {"flash_amount": 0.35})
	_panel(root, Vector2(520, 20), "hit_flash=1.0", z, "res://shaders/zombie_hit_flash.gdshader", {"flash_amount": 1.0})

	# 血液：空中血雾 / 淡出 / 地面血渍
	_panel(root, Vector2(770, 20), "blood_fog", b, "res://shaders/blood_hit_effect.gdshader", {"fade": 0.0})
	_panel(root, Vector2(20, 340), "blood_fade=0.6", b, "res://shaders/blood_hit_effect.gdshader", {"fade": 0.6})
	_panel(root, Vector2(270, 340), "blood_decal", checker, "res://shaders/blood_hit_effect.gdshader", {"darken_only": true})

	# 枪口火光：三个阶段
	_panel(root, Vector2(520, 340), "muzzle=0.15", null, "res://shaders/muzzle_flash.gdshader", {"lifetime": 0.15})
	_panel(root, Vector2(770, 340), "muzzle=0.55", null, "res://shaders/muzzle_flash.gdshader", {"lifetime": 0.55})


func _save(n: String) -> void:
	var p := ProjectSettings.globalize_path(OUT + "/" + n + ".png")
	root.get_texture().get_image().save_png(p)
	print("SAVED ", p)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 8:
		_save("A_effects")
		# 关掉 CRT，只看量化 + 调色
		var post := ShaderMaterial.new()
		post.shader = load("res://shaders/pixelzombie_postprocess.gdshader")
		post.set_shader_parameter("enable_crt", false)
		post.set_shader_parameter("palette_levels", 5.0)
		post.set_shader_parameter("dither_strength", 1.0)
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 1)
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.material = post
		root.add_child(r)
		_m["post_off"] = post
		_m["post_rect"] = r
	elif _f == 16:
		_save("B_quantize_only")
		var post: ShaderMaterial = _m["post_off"]
		post.set_shader_parameter("enable_crt", true)
		post.set_shader_parameter("pixel_size", 3.0)
		post.set_shader_parameter("curvature", 0.06)
		post.set_shader_parameter("palette_levels", 8.0)
	elif _f == 24:
		_save("C_crt_pixel3")
		(_m["post_rect"] as ColorRect).queue_free()
		var pal := ShaderMaterial.new()
		pal.shader = load("res://shaders/retro_palette_filter.gdshader")
		pal.set_shader_parameter("filter_strength", 1.0)
		pal.set_shader_parameter("vignette", 0.0)
		var r2 := ColorRect.new()
		r2.color = Color(1, 1, 1, 1)
		r2.set_anchors_preset(Control.PRESET_FULL_RECT)
		r2.material = pal
		root.add_child(r2)
		_m["pal_rect"] = r2
	elif _f == 32:
		_save("D_palette_full")
		return true
	return false
