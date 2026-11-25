# 最终验收 v2：分状态推进，每个状态稳定 3 帧后再抓帧（消除参数/标签的一帧延迟）。
# 用法：godot --path D:\mygame --rendering-driver opengl3 --resolution 1280x720 --script res://tmp/vcheck7.gd
extends SceneTree

const OUT_DIR := "res://tmp/out"
const SHADER_DIR := "res://shaders"

var _frame := 0
var _root: Node
var _label: Label
var _mats: Dictionary = {}
var _states: Array = []
var _state_index := -1
var _settle := 0

func _make_zombie(pose: int) -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(5, 14):
		for x in range(5, 11):
			img.set_pixel(x, y, Color(0.34, 0.42, 0.26) if y < 8 else Color(0.28, 0.36, 0.22))
	for y in range(2, 6):
		for x in range(5, 11):
			img.set_pixel(x, y, Color(0.46, 0.42, 0.30))
	img.set_pixel(6 + pose, 4, Color(0.9, 0.15, 0.10))
	img.set_pixel(9 - pose, 4, Color(0.9, 0.15, 0.10))
	for y in range(7, 11):
		img.set_pixel(4 - (pose % 2), y, Color(0.30, 0.38, 0.24))
		img.set_pixel(11 + (pose % 2), y, Color(0.30, 0.38, 0.24))
	return ImageTexture.create_from_image(img)

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

	# 丧尸闪白 4 档（各自独立贴图，模拟换方向）
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

	# 血雾 4 档 fade
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

	# 地面血渍
	var dmat := bbase.duplicate() as ShaderMaterial
	dmat.set_shader_parameter("albedo_texture", blood_tex)
	dmat.set_shader_parameter("sprite_size", Vector2(32, 32))
	dmat.set_shader_parameter("darken_only", true)
	var decal := _sprite3d(world, blood_tex, dmat, Vector3(0.0, 0.02, 1.1), 0.05)
	decal.rotation_degrees = Vector3(-90, 0, 0)
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED

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

	# 枪口火光 4 档
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

	# 主后期
	var post_rect := ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.material = _mat("pixelzombie_postprocess.gdshader")
	hud.add_child(post_rect)

	# 调色板滤镜
	var pal_rect := ColorRect.new()
	pal_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pal_rect.material = _mat("retro_palette_filter.gdshader")
	hud.add_child(pal_rect)

	_label = Label.new()
	_label.position = Vector2(24, 340)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_label)

	# 状态表：label / 截图名 / 要写入的 uniform
	_states = [
		{
			"label": "A 全特效：pixel_size=1, 量化8阶+抖动, CRT开, 调色板0.6",
			"shot": "V7_A_full.png",
			"params": {
				"pixelzombie_postprocess.gdshader": {
					"pixel_size": 1.0, "palette_levels": 8.0, "dither_strength": 1.0,
					"saturation": 0.85, "contrast": 1.06, "enable_crt": true,
					"scanline_strength": 0.18, "vignette_strength": 0.35
				},
				"retro_palette_filter.gdshader": {"filter_strength": 0.6}
			}
		},
		{
			"label": "B 关 CRT/调色板：只留像素化+量化",
			"shot": "V7_B_nocrt.png",
			"params": {
				"pixelzombie_postprocess.gdshader": {"enable_crt": false},
				"retro_palette_filter.gdshader": {"filter_strength": 0.0}
			}
		},
		{
			"label": "C 路线B 直出：pixel_size=4, CRT开, 调色板0.6",
			"shot": "V7_C_routeB.png",
			"params": {
				"pixelzombie_postprocess.gdshader": {"pixel_size": 4.0, "enable_crt": true},
				"retro_palette_filter.gdshader": {"filter_strength": 0.6}
			}
		},
		{
			"label": "D 归零：无量化/无抖动/无CRT/无暗角/无调色",
			"shot": "V7_D_zero.png",
			"params": {
				"pixelzombie_postprocess.gdshader": {
					"pixel_size": 1.0, "palette_levels": 32.0, "dither_strength": 0.0,
					"saturation": 1.0, "contrast": 1.0, "enable_crt": false,
					"vignette_strength": 0.0, "brightness": 1.0, "lift": 0.0
				},
				"retro_palette_filter.gdshader": {"filter_strength": 0.0}
			}
		}
	]

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

func _apply_state(i: int) -> void:
	var st: Dictionary = _states[i]
	_label.text = str(st["label"])
	var per: Dictionary = st["params"]
	for shader_file in per.keys():
		var mat: ShaderMaterial = _mats[shader_file]
		var kv: Dictionary = per[shader_file]
		for k in kv.keys():
			mat.set_shader_parameter(k, kv[k])

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 4:
		return false

	# 每 4 帧推进一个状态：第 1 帧写入参数，第 4 帧抓图（留足重绘时间）
	var phase := (_frame - 4) % 4
	if phase == 0:
		_state_index += 1
		if _state_index >= _states.size():
			print("VERIFY DONE")
			return true
		_apply_state(_state_index)
	elif phase == 3:
		_shot(str(_states[_state_index]["shot"]))
	return false

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		push_error("抓帧失败: " + name)
		return
	var path := OUT_DIR + "/" + name
	var err := img.save_png(path)
	print("SHOT ", path, " err=", err)
