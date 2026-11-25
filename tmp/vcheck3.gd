# 定点验证两件事：
#  1) muzzle_flash 用 ColorRect（无贴图）能否正常出图
#  2) Sprite3D 到底吃 canvas_item 还是 spatial 着色器
# 用法：godot --path D:\mygame --rendering-driver opengl3 --resolution 1280x720 --script res://tmp/vcheck3.gd
extends SceneTree

const OUT := "res://tmp/out"
var _f := 0


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


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# --- 上半屏：2D 层，验证 muzzle 用 ColorRect ---
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var x := 40.0
	for lt in [0.1, 0.35, 0.7]:
		var r := ColorRect.new()
		r.position = Vector2(x, 30)
		r.size = Vector2(200, 160)
		r.color = Color(0.05, 0.05, 0.06)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/muzzle_flash.gdshader")
		m.set_shader_parameter("lifetime", lt)
		m.set_shader_parameter("random_seed", 0.42)
		r.material = m
		root.add_child(r)
		var lb := Label.new()
		lb.text = "muzzle ColorRect t=%.2f" % lt
		lb.position = Vector2(x, 196)
		root.add_child(lb)
		x += 250.0

	# --- 下半屏：Sprite3D 三种挂法对比，用 SubViewport 抓 3D ---
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 460)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 4.0)
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 4.0), Vector3(0, 1.0, 0))

	var amb := DirectionalLight3D.new()
	amb.rotation_degrees = Vector3(-40, 20, 0)
	world.add_child(amb)

	var ztex := _zombie()

	# A: 无 material_override（对照组）
	var a := Sprite3D.new()
	a.texture = ztex
	a.pixel_size = 0.02
	a.position = Vector3(-2.4, 1.0, 0)
	a.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	world.add_child(a)

	# B: material_override = canvas_item 着色器（受击闪白）
	var b := Sprite3D.new()
	b.texture = ztex
	b.pixel_size = 0.02
	b.position = Vector3(-0.8, 1.0, 0)
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/zombie_hit_flash.gdshader")
	bm.set_shader_parameter("flash_amount", 1.0)
	b.material_override = bm
	world.add_child(b)

	# C: 只改 modulate（兜底方案）
	var c := Sprite3D.new()
	c.texture = ztex
	c.pixel_size = 0.02
	c.position = Vector3(0.8, 1.0, 0)
	c.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	c.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	c.modulate = Color(2.0, 2.0, 2.0, 1.0)
	world.add_child(c)

	# D: material_override = StandardMaterial3D（贴图 + 自发光闪白）
	var d := Sprite3D.new()
	d.texture = ztex
	d.pixel_size = 0.02
	d.position = Vector3(2.4, 1.0, 0)
	d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = ztex
	dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dm.emission_enabled = true
	dm.emission = Color(1, 1, 1)
	dm.emission_energy_multiplier = 1.0
	d.material_override = dm
	world.add_child(d)

	var rt := TextureRect.new()
	rt.texture = vp.get_texture()
	rt.position = Vector2(0, 260)
	rt.size = Vector2(1280, 460)
	rt.stretch_mode = TextureRect.STRETCH_SCALE
	rt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(rt)

	var tags := ["A_no_material", "B_canvas_item_shader", "C_self_modulate", "D_standard_emit"]
	var i := 0
	for t in tags:
		var lb2 := Label.new()
		lb2.text = t
		lb2.position = Vector2(60 + i * 300, 250)
		root.add_child(lb2)
		i += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f == 10:
		var p := ProjectSettings.globalize_path(OUT + "/E_mount_test.png")
		root.get_texture().get_image().save_png(p)
		print("SAVED ", p)
		return true
	return false
