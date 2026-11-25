# 定点验证：Sprite3D 是否能吃 spatial 着色器（对比 canvas_item）
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
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 5.0), Vector3(0, 1.0, 0))

	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-40, 20, 0)
	world.add_child(lt)

	var ztex := _zombie()

	# 1) canvas_item 着色器挂 Sprite3D
	var s1 := Sprite3D.new()
	s1.texture = ztex
	s1.pixel_size = 0.05
	s1.position = Vector3(-1.5, 1.0, 0)
	s1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s1.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var m1 := ShaderMaterial.new()
	m1.shader = load("res://shaders/zombie_hit_flash.gdshader")
	m1.set_shader_parameter("flash_amount", 1.0)
	s1.material_override = m1
	world.add_child(s1)

	# 2) spatial 着色器挂 Sprite3D
	var s2 := Sprite3D.new()
	s2.texture = ztex
	s2.pixel_size = 0.05
	s2.position = Vector3(0.0, 1.0, 0)
	s2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var m2 := ShaderMaterial.new()
	m2.shader = load("res://tmp/spatial_texture_test.gdshader")
	
	m2.set_shader_parameter("flash_amount", 1.0)
	s2.material_override = m2
	world.add_child(s2)

	# 3) 无材质对照
	var s3 := Sprite3D.new()
	s3.texture = ztex
	s3.pixel_size = 0.05
	s3.position = Vector3(1.5, 1.0, 0)
	s3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	world.add_child(s3)

	var rt := TextureRect.new()
	rt.texture = vp.get_texture()
	rt.set_anchors_preset(Control.PRESET_FULL_RECT)
	rt.stretch_mode = TextureRect.STRETCH_SCALE
	rt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(rt)

	var names := ["canvas_item_shader", "spatial_shader", "no_material"]
	var i := 0
	for n in names:
		var lb := Label.new()
		lb.text = n
		lb.position = Vector2(500 + i * 60, 20)
		root.add_child(lb)
		i += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f == 10:
		var p := ProjectSettings.globalize_path(OUT + "/G_spatial_TEXTURE.png")
		root.get_texture().get_image().save_png(p)
		print("SAVED ", p)
		return true
	return false
