# 视觉验证：在真实 opengl3 窗口里跑一遍五个着色器，抓帧存 PNG。
# 用法：godot --path D:\mygame --rendering-driver opengl3 --resolution 960x540 --script res://tmp/visual_check.gd
extends SceneTree

const OUT_DIR := "res://tmp/out"

var _frames := 0
var _shot := 0
var _viewport: SubViewport
var _zombie_mat: ShaderMaterial
var _muzzle_mat: ShaderMaterial
var _blood_mat: ShaderMaterial
var _post_rect: ColorRect
var _post_mat: ShaderMaterial
var _palette_rect: ColorRect
var _palette_mat: ShaderMaterial


func _make_checker(w: int, h: int, c1: Color, c2: Color, cell: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := c1 if ((x / cell) + (y / cell)) % 2 == 0 else c2
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_zombie_sprite() -> ImageTexture:
	# 16x16 简易丧尸剪影：身体 + 头，周围透明
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(0.35, 0.45, 0.30, 1.0)
	var head := Color(0.62, 0.55, 0.42, 1.0)
	for y in range(6, 16):
		for x in range(5, 11):
			img.set_pixel(x, y, body)
	for y in range(2, 7):
		for x in range(5, 11):
			img.set_pixel(x, y, head)
	return ImageTexture.create_from_image(img)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# --- 3D 世界（塞进 SubViewport，模拟 PDF 的 480x270 低分渲染） ---
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 270)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 3.2)
	cam.look_at_from_position(Vector3(0, 1.2, 3.2), Vector3(0, 1.0, 0))
	world.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	world.add_child(sun)

	# 地面
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0, 0, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = _make_checker(64, 64, Color(0.30, 0.29, 0.26), Color(0.22, 0.21, 0.19), 8)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mesh.material_override = floor_mat
	world.add_child(floor_mesh)

	# 丧尸纸片人（Sprite3D + 受击闪白着色器）
	var zombie := Sprite3D.new()
	zombie.texture = _make_zombie_sprite()
	zombie.pixel_size = 0.06
	zombie.position = Vector3(0, 0.48, 0)
	zombie.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zombie.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_zombie_mat = ShaderMaterial.new()
	_zombie_mat.shader = load("res://shaders/zombie_hit_flash.gdshader")
	_zombie_mat.set_shader_parameter("flash_amount", 1.0)
	_zombie_mat.set_shader_parameter("rim_boost", 0.35)
	zombie.material_override = _zombie_mat
	world.add_child(zombie)

	# 血雾精灵（Sprite3D + 血液着色器）
	var blood := Sprite3D.new()
	blood.texture = _make_checker(16, 16, Color(0.9, 0.1, 0.1), Color(0.4, 0.05, 0.05), 2)
	blood.pixel_size = 0.03
	blood.position = Vector3(-0.9, 0.9, 0.2)
	blood.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_blood_mat = ShaderMaterial.new()
	_blood_mat.shader = load("res://shaders/blood_hit_effect.gdshader")
	_blood_mat.set_shader_parameter("fade", 0.25)
	blood.material_override = _blood_mat
	world.add_child(blood)

	# 地面血渍（darken_only）
	var decal := Sprite3D.new()
	decal.texture = _make_checker(16, 16, Color(0.95, 0.95, 0.95), Color(0.2, 0.2, 0.2), 3)
	decal.pixel_size = 0.02
	decal.position = Vector3(0.9, 0.01, 0.6)
	decal.rotation_degrees = Vector3(-90, 0, 0)
	decal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var decal_mat := ShaderMaterial.new()
	decal_mat.shader = load("res://shaders/blood_hit_effect.gdshader")
	decal_mat.set_shader_parameter("darken_only", true)
	decal.material_override = decal_mat
	world.add_child(decal)

	# --- 窗口层：低分画面放大 + 主后期 ---
	var layer := CanvasLayer.new()
	root.add_child(layer)

	var screen_rect := TextureRect.new()
	screen_rect.texture = _viewport.get_texture()
	screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_rect.stretch_mode = TextureRect.STRETCH_SCALE
	screen_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen_rect)

	# 枪口火光（HUD 层 TextureRect + muzzle 着色器）
	var muzzle := TextureRect.new()
	muzzle.set_anchors_preset(Control.PRESET_CENTER)
	muzzle.size = Vector2(220, 160)
	muzzle.position = Vector2(-110 + 250, -80 + 120)
	muzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muzzle_mat = ShaderMaterial.new()
	_muzzle_mat.shader = load("res://shaders/muzzle_flash.gdshader")
	_muzzle_mat.set_shader_parameter("lifetime", 0.25)
	_muzzle_mat.set_shader_parameter("random_seed", 0.37)
	muzzle.material = _muzzle_mat
	layer.add_child(muzzle)

	# 主后期（量化 + 抖动 + CRT）
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.color = Color(1, 1, 1, 1)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://shaders/pixelzombie_postprocess.gdshader")
	_post_mat.set_shader_parameter("pixel_size", 1.0)
	_post_mat.set_shader_parameter("palette_levels", 8.0)
	_post_rect.material = _post_mat
	layer.add_child(_post_rect)

	# 调色板滤镜（再叠一层，验证 filter_strength=0 时不干扰）
	_palette_rect = ColorRect.new()
	_palette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_palette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette_mat = ShaderMaterial.new()
	_palette_mat.shader = load("res://shaders/retro_palette_filter.gdshader")
	_palette_mat.set_shader_parameter("filter_strength", 0.0)
	_palette_mat.set_shader_parameter("vignette", 0.0)
	_palette_rect.material = _palette_mat
	layer.add_child(_palette_rect)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name + ".png")
	img.save_png(path)
	print("SAVED ", path, " size=", img.get_size())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_save("01_base")
		# 关掉 CRT，只留像素化 + 量化
		_post_mat.set_shader_parameter("enable_crt", false)
		_palette_mat.set_shader_parameter("filter_strength", 0.7)
	elif _frames == 12:
		_save("02_no_crt_palette")
		# 极硬核量化 + 大像素块（路线 B）
		_post_mat.set_shader_parameter("enable_crt", true)
		_post_mat.set_shader_parameter("pixel_size", 4.0)
		_post_mat.set_shader_parameter("palette_levels", 4.0)
		_palette_mat.set_shader_parameter("filter_strength", 0.0)
	elif _frames == 18:
		_save("03_hard_pixel")
		# 受击闪白归零 + 血雾淡出，验证 0 强度时是原画
		_zombie_mat.set_shader_parameter("flash_amount", 0.0)
		_blood_mat.set_shader_parameter("fade", 0.0)
		_muzzle_mat.set_shader_parameter("lifetime", 0.95)
		_post_mat.set_shader_parameter("pixel_size", 1.0)
		_post_mat.set_shader_parameter("palette_levels", 8.0)
	elif _frames == 24:
		_save("04_zero_state")
		return true
	return false
