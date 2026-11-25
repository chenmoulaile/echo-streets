# 验证 spatial 版特效着色器在 Sprite3D 上的真实效果（贴图显式绑定）
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
	var amounts := [0.0, 0.5, 1.0]
	var i := 0
	for a in amounts:
		var s := Sprite3D.new()
		s.texture = ztex
		s.pixel_size = 0.05
		s.position = Vector3(-1.6 + i * 1.6, 1.0, 0)
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var m := ShaderMaterial.new()
		m.shader = load("res://tmp/v_a.gdshader")
		m.set_shader_parameter("albedo_texture", ztex)
		m.set_shader_parameter("flash_amount", a)
		s.material_override = m
		world.add_child(s)
		i += 1

	var rt := TextureRect.new()
	rt.texture = vp.get_texture()
	rt.set_anchors_preset(Control.PRESET_FULL_RECT)
	rt.stretch_mode = TextureRect.STRETCH_SCALE
	rt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(rt)

	var lb := Label.new()
	lb.text = "spatial flash 0.0 / 0.5 / 1.0"
	lb.position = Vector2(20, 20)
	root.add_child(lb)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 10:
		var p := ProjectSettings.globalize_path(OUT + "/H_spatial_flash.png")
		root.get_texture().get_image().save_png(p)
		print("SAVED ", p)
		return true
	return false
