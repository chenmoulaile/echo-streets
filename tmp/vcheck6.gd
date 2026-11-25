# 最终验收：真实渲染管线里挂载全部 7 个 .gdshader，抓帧 + uniform 清单。
# 用法：godot --path D:\mygame --rendering-driver opengl3 --resolution 1280x720 --script res://tmp/vcheck6.gd
extends SceneTree

const OUT_DIR := "res://tmp/out"
const SHADER_DIR := "res://shaders"

var _frame := 0
var _root: Node
var _label: Label
var _mats: Dictionary = {}

# 程序化丧尸剪影（单帧 16x16）。pose 让每张略有差别，用于确认"换贴图"生效。
func _make_zombie(pose: int) -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(5, 14):
		for x in range(5, 11):
			var c := Color(0.28, 0.36, 0.22)
			if y < 8:
				c = Color(0.34, 0.42, 0.26)
			img.set_pixel(x, y, c)
	for y in range(2, 6):
		for x in range(5, 11):
			img.set_pixel(x, y, Color(0.46, 0.42, 0.30))
	img.set_pixel(6 + pose, 4, Color(0.9, 0.15, 0.10))
	img.set_pixel(9 - pose, 4, Color(0.9, 0.15, 0.10))
	for y in range(7, 11):
		img.set_pixel(4 - (pose % 2), y, Color(0.30, 0.38, 0.24))
		img.set_pixel(11 + (pose % 2), y, Color(0.30, 0.38, 0.24))
	return ImageTexture.create_from_image(img)

# 程序化血雾贴图（32x32 圆形噪声团）
func _make_blood_tex() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s * 0.5, s * 0.5)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
			if d < 1.0:
				var a := 1.0 - d * d
				var n := 0.75 + 0.25 * sin(float(x * 7 + y * 13))
				img.set_pixel(x, y, Color(n, n * 0.9, n * 0.85, a))
	return ImageTexture.create_from_image(img)

# 程序化棋盘地面贴图
func _make_checker() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := 0.30 if ((x / 4 + y / 4) % 2 == 0) else 0.20
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.92))
	return ImageTexture.create_from_image(img)

func _mat(shader_file: String) -> ShaderMaterial:
	var sh: Shader = load(SHADER_DIR + "/" + shader_file)
	if sh == null:
		push_error("加载失败: " + shader_file)
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	_mats[shader_file] = m
	return m

func _sprite3d(parent: Node3D, tex: Texture2D, mat: ShaderMaterial, pos: Vector3, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = size
	s.position = pos
	s.material_override = mat
	parent.add_child(s)
	return s

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_root = Node.new()
	root.add_child(_root)

	# ---------------- 3D 世界（SubViewport 480x270 低分辨率） ----------------
	var sv := SubViewport.new()
	sv.size = Vector2i(480, 270)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	sv.msaa_3d = Viewport.MSAA_DISABLED
	_root.add_child(sv)

	var world := Node3D.new()
	sv.add_child(world)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 3.2)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 70.0
	world.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.1
	world.add_child(light)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24, 24)
	floor_mi.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = _make_checker()
	fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fmat.roughness = 0.95
	floor_mi.material_override = fmat
	world.add_child(floor_mi)

	var blood_tex := _make_blood_tex()

	# ---- 丧尸闪白：4 档 flash_amount，各自独立贴图（模拟换帧/换方向） ----
	var zbase := _mat("zombie_hit_flash.gdshader")
	var flashes := [0.0, 0.35, 0.7, 1.0]
	var zx := -2.4
	for i in flashes.size():
		var tex := _make_zombie(i)
		var m := zbase.duplicate() as ShaderMaterial
		m.set_shader_parameter("albedo_texture", tex)
		m.set_shader_parameter("sprite_size", Vector2(16, 16))
		m.set_shader_parameter("flip_h", i == 3)
		m.set_shader_parameter("flash_amount", float(flashes[i]))
		_sprite3d(world, tex, m, Vector3(zx, 0.9, 0.0), 0.055)
		zx += 1.6

	# ---- 血雾（空中）4 档 fade ----
	var bbase := _mat("blood_hit_effect.gdshader")
	var fades := [0.0, 0.35, 0.7, 0.95]
	var bx := -2.4
	for i in fades.size():
		var m := bbase.duplicate() as ShaderMaterial
		m.set_shader_parameter("albedo_texture", blood_tex)
		m.set_shader_parameter("sprite_size", Vector2(32, 32))
		m.set_shader_parameter("fade", float(fades[i]))
		_sprite3d(world, blood_tex, m, Vector3(bx, 1.5, -0.9), 0.045)
		bx += 1.6

	# ---- 地面血渍（darken_only）----
	var dmat := bbase.duplicate() as ShaderMaterial
	dmat.set_shader_parameter("albedo_texture", blood_tex)
	dmat.set_shader_parameter("sprite_size", Vector2(32, 32))
	dmat.set_shader_parameter("darken_only", true)
	var decal := _sprite3d(world, blood_tex, dmat, Vector3(0.0, 0.02, 1.1), 0.05)
	decal.rotation_degrees = Vector3(-90, 0, 0)
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# ---------------- 2D HUD 层 ----------------
	var layer := CanvasLayer.new()
	layer.layer = 2
	_root.add_child(layer)

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

	var world_rect := TextureRect.new()
	world_rect.texture = sv.get_texture()
	world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(world_rect)

	# 枪口火光（4 档 lifetime）
	var mz := _mat("muzzle_flash.gdshader")
	var lifes := [0.08, 0.30, 0.55, 0.85]
	for i in lifes.size():
		var r := ColorRect.new()
		r.size = Vector2(150, 150)
		r.position = Vector2(40 + i * 165, 40)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := mz.duplicate() as ShaderMaterial
		m.set_shader_parameter("lifetime", float(lifes[i]))
		m.set_shader_parameter("random_seed", 0.37 + float(i) * 0.11)
		r.material = m
		hud.add_child(r)

	# 2D 闪白 3 档
	var z2 := _mat("zombie_hit_flash_2d.gdshader")
	var z2tex := _make_zombie(0)
	for i in 3:
		var r := TextureRect.new()
		r.texture = z2tex
		r.size = Vector2(96, 96)
		r.position = Vector2(40 + i * 110, 220)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := z2.duplicate() as ShaderMaterial
		m.set_shader_parameter("flash_amount", 0.0 if i == 0 else (0.5 if i == 1 else 1.0))
		r.material = m
		hud.add_child(r)

	# 2D 血雾 3 档
	var b2 := _mat("blood_hit_effect_2d.gdshader")
	for i in 3:
		var r := TextureRect.new()
		r.texture = blood_tex
		r.size = Vector2(96, 96)
		r.position = Vector2(380 + i * 110, 220)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := b2.duplicate() as ShaderMaterial
		m.set_shader_parameter("fade", 0.0 if i == 0 else (0.4 if i == 1 else 0.85))
		r.material = m
		hud.add_child(r)

	# 主后期：像素化 + 量化 + CRT
	var post := _mat("pixelzombie_postprocess.gdshader")
	var post_rect := ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.material = post
	hud.add_child(post_rect)

	# 调色板滤镜
	var pal := _mat("retro_palette_filter.gdshader")
	var pal_rect := ColorRect.new()
	pal_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pal_rect.material = pal
	hud.add_child(pal_rect)

	_label = Label.new()
	_label.position = Vector2(24, 340)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_label)

	print("===== UNIFORM AUDIT =====")
	var keys := _mats.keys()
	keys.sort()
	for n in keys:
		var m: ShaderMaterial = _mats[n]
		var list: Array = m.shader.get_shader_uniform_list()
		var parts: Array = []
		for u in list:
			parts.append(str(u.get("name", "?")))
		print(n, "  count=", list.size())
		print("   ", ", ".join(parts))
	print("===== END AUDIT =====")

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		_label.text = "A: 全特效 (pixel_size=1, CRT on, palette 0.6)"
		_shot("V6_A_full.png")
	if _frame == 16:
		(_mats["pixelzombie_postprocess.gdshader"] as ShaderMaterial).set_shader_parameter("enable_crt", false)
		(_mats["retro_palette_filter.gdshader"] as ShaderMaterial).set_shader_parameter("filter_strength", 0.0)
		_label.text = "B: CRT off, palette 0"
		_shot("V6_B_clean.png")
	if _frame == 24:
		(_mats["pixelzombie_postprocess.gdshader"] as ShaderMaterial).set_shader_parameter("pixel_size", 4.0)
		(_mats["pixelzombie_postprocess.gdshader"] as ShaderMaterial).set_shader_parameter("enable_crt", true)
		(_mats["retro_palette_filter.gdshader"] as ShaderMaterial).set_shader_parameter("filter_strength", 0.6)
		_label.text = "C: pixel_size=4 (route B), CRT on"
		_shot("V6_C_hardpixel.png")
	if _frame == 32:
		var p := _mats["pixelzombie_postprocess.gdshader"] as ShaderMaterial
		p.set_shader_parameter("pixel_size", 1.0)
		p.set_shader_parameter("enable_crt", false)
		p.set_shader_parameter("palette_levels", 32.0)
		p.set_shader_parameter("dither_strength", 0.0)
		p.set_shader_parameter("saturation", 1.0)
		p.set_shader_parameter("contrast", 1.0)
		p.set_shader_parameter("vignette_strength", 0.0)
		(_mats["retro_palette_filter.gdshader"] as ShaderMaterial).set_shader_parameter("filter_strength", 0.0)
		_label.text = "D: all effects zeroed"
		_shot("V6_D_zero.png")
	if _frame >= 40:
		print("VERIFY DONE")
		return true
	return false

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		push_error("抓帧失败: " + name)
		return
	var path := OUT_DIR + "/" + name
	var err := img.save_png(path)
	print("SHOT ", path, " err=", err)
