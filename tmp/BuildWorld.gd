## 场景与关卡构建器：用 Godot 自己的序列化器产出 .tscn，避免手写格式出错。
## 必须在完整场景树里跑：--script 模式不加载 Autoload，EventBus / GameManager 会编译失败。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame --headless res://tmp/build_runner.tscn
extends Node

const SCENES := "res://scenes/"
const DATA := "res://data/"
const TEX := "res://assets/textures/"
const SPR := "res://assets/sprites/"

# ── 材质与网格工具 ──────────────────────────────────────────────

func _mat(tex_path: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# 无光照：兼容渲染器下最稳，也更贴近"贴图即画面"的复古观感
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m

func _box(size: Vector3, pos: Vector3, mat: Material, with_body: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if with_body else Node3D.new()
	root.position = pos
	if with_body:
		var body := root as StaticBody3D
		body.collision_layer = GameLayers.WORLD
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		root.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mesh_inst.mesh = mesh
	root.add_child(mesh_inst)
	return root

# ── 丧尸 ────────────────────────────────────────────────────────

func _zombie_material(tex_path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/zombie_hit_flash.gdshader")
	m.set_shader_parameter(&"albedo_texture", load(tex_path))
	m.set_shader_parameter(&"sprite_size", Vector2(128.0, 96.0))
	return m

func _build_zombie(file_name: String, tex: String, speed: float, hp: float,
		dmg: float, body_height: float) -> void:
	var root := CharacterBody3D.new()
	root.name = "Zombie"
	root.set_script(load("res://scripts/enemies/zombie.gd"))
	root.set(&"move_speed", speed)
	root.set(&"max_health", hp)
	root.set(&"attack_damage", dmg)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = body_height
	col.shape = cap
	col.position = Vector3(0.0, body_height * 0.5, 0.0)
	root.add_child(col)

	var hc := Node.new()
	hc.name = "HealthComponent"
	hc.set_script(load("res://scripts/components/health_component.gd"))
	hc.set(&"max_health", hp)
	root.add_child(hc)

	# 帧动画贴图前缀（zombie_fodder 等）。动画帧是 128x96，比原始 96x96 宽，
	# 因为倒地帧要横躺——96 宽会把头和脚裁掉。身体仍居中占据 96px，
	# 所以 pixel_size 依旧按 96 高换算，视觉尺寸不变。
	var prefix: String = tex.get_file().get_basename()
	var first_frame: String = "res://assets/sprites/zombie_frames/" + prefix + "_idle_0.png"
	var base_tex: String = first_frame if ResourceLoader.exists(first_frame) else tex
	var spr := Sprite3D.new()
	spr.name = "Sprite3D"
	spr.set_script(load("res://scripts/enemies/zombie_sprite.gd"))
	spr.set(&"frame_prefix", prefix)
	spr.texture = load(base_tex)
	# pixel_size = 目标世界高度 / 贴图像素高度，保证 96 高的贴图撑满 body_height
	spr.pixel_size = body_height / 96.0
	spr.position = Vector3(0.0, body_height * 0.5, 0.0)
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.material_override = _zombie_material(base_tex)
	root.add_child(spr)

	# 弱点 Area3D：头部，layer=WEAKSPOT，必须入组 Weakspot 才能被 Weapon 识别
	var weak := Area3D.new()
	weak.name = "Weakspot"
	weak.collision_layer = GameLayers.WEAKSPOT
	weak.collision_mask = 0
	weak.monitoring = false
	weak.position = Vector3(0.0, body_height - 0.22, 0.0)
	weak.add_to_group(GameLayers.GROUP_WEAKSPOT)
	var wcol := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.18
	wcol.shape = sph
	weak.add_child(wcol)
	root.add_child(weak)

	_pack(root, SCENES + file_name)

# ── 玩家 ────────────────────────────────────────────────────────

func _weapon_node(node_name: String, data_path: String) -> Node3D:
	var w := Node3D.new()
	w.name = node_name
	w.set_script(load("res://scripts/weapons/weapon.gd"))
	w.set(&"data", load(data_path))
	# Player 在 _ready 里才入组，而 Weapon._ready 更早执行 → group 兜底拿不到玩家，
	# 必须显式给路径：Pistol → WeaponMount → Camera3D → CameraRig → Player
	w.set(&"shooter_path", ^"../../../..")
	return w

func _build_player() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	root.set_script(load("res://scripts/player/player.gd"))

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(col)

	var hc := Node.new()
	hc.name = "HealthComponent"
	hc.set_script(load("res://scripts/components/health_component.gd"))
	hc.set(&"max_health", 100.0)
	root.add_child(hc)

	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.position = Vector3(0.0, 1.6, 0.0)
	root.add_child(rig)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 75.0
	cam.current = true
	cam.near = 0.05
	rig.add_child(cam)

	var mount := Node3D.new()
	mount.name = "WeaponMount"
	mount.position = Vector3(0.3, -0.25, -0.5)
	cam.add_child(mount)

	# 子节点顺序即槽位顺序：0 手枪、1 霰弹枪
	mount.add_child(_weapon_node("Pistol", DATA + "weapon_pistol.tres"))
	mount.add_child(_weapon_node("Shotgun", DATA + "weapon_shotgun.tres"))
	_pack(root, SCENES + "player.tscn")

# ── 刷怪器与导演 ────────────────────────────────────────────────

func _build_spawner() -> void:
	var root := Node3D.new()
	root.name = "WaveSpawner"
	root.set_script(load("res://scripts/director/wave_spawner.gd"))

	var pts := Node3D.new()
	pts.name = "SpawnPoints"
	root.add_child(pts)
	# 走廊 20x44，刷怪点贴两侧墙外与两端，全部距出生点 > 8 米
	var spots: Array[Vector3] = [
		Vector3(-8.0, 0.0, -18.0), Vector3(8.0, 0.0, -18.0),
		Vector3(-8.0, 0.0, -8.0), Vector3(8.0, 0.0, -8.0),
		Vector3(-8.0, 0.0, 2.0), Vector3(8.0, 0.0, 2.0),
		Vector3(-8.0, 0.0, 12.0), Vector3(8.0, 0.0, 12.0),
		Vector3(-8.0, 0.0, 19.0), Vector3(8.0, 0.0, 19.0),
		Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, 20.0),
	]
	for i: int in spots.size():
		var m := Marker3D.new()
		m.name = "P%02d" % (i + 1)
		m.position = spots[i]
		pts.add_child(m)

	var pools := Node3D.new()
	pools.name = "Pools"
	root.add_child(pools)

	root.set(&"pool_initial_size", 24)
	root.set(&"pool_max_size", 64)
	root.set(&"min_player_distance", 8.0)
	_pack(root, SCENES + "wave_spawner.tscn")

func _build_director() -> void:
	var root := Node.new()
	root.name = "Director"
	root.set_script(load("res://scripts/director/director.gd"))
	_pack(root, SCENES + "director.tscn")

# ── 波次配置 ────────────────────────────────────────────────────

func _build_waves() -> void:
	var specials: Array[PackedScene] = [
		load(SCENES + "zombie_charger.tscn"),
		load(SCENES + "zombie_bomber.tscn"),
		load(SCENES + "zombie_screamer.tscn"),
	]
	for i: int in 5:
		var cfg := WaveConfig.new()
		cfg.total_count = 8 + 4 * i
		cfg.max_alive = mini(10 + 6 * i, 28)
		cfg.spawn_interval = maxf(1.0 - 0.12 * i, 0.35)
		cfg.prepare_time = 3.0 if i == 0 else 2.5
		cfg.rest_time = 4.0
		cfg.fodder_scene = load(SCENES + "zombie_fodder.tscn")
		cfg.special_scenes = specials
		cfg.special_weights = [0.45, 0.3, 0.25]
		cfg.special_ratio = 0.12 + 0.06 * i
		cfg.speed_multiplier = 1.0 + 0.06 * i
		cfg.health_multiplier = 1.0 + 0.12 * i
		for issue: String in cfg.validate():
			push_error("WaveConfig %d: %s" % [i, issue])
		var err := ResourceSaver.save(cfg, DATA + "wave_%d.tres" % (i + 1))
		if err != OK:
			push_error("保存 wave_%d 失败 err=%d" % [i + 1, err])
		else:
			print("[build_world] wrote ", DATA + "wave_%d.tres" % (i + 1))

# ── 主关卡 ──────────────────────────────────────────────────────

func _build_world_geometry(parent: Node3D) -> void:
	var stone := _mat(TEX + "wall_stone.png")
	# tint 不能再压亮度：实测旧版 floor 0.82 / ceiling 0.55 叠加后期后地面只剩 7、
	# 天花板 0。现在纹理已提亮，tint 回到接近白色，只做轻微冷暖区分。
	var floor_mat := _mat(TEX + "floor_tile.png", Color(0.95, 0.95, 0.98))
	var ceil_mat := _mat(TEX + "ceiling.png", Color(0.90, 0.90, 0.94))

	parent.add_child(_box(Vector3(20.0, 0.4, 44.0), Vector3(0.0, -0.2, 0.0), floor_mat))
	parent.add_child(_box(Vector3(20.0, 0.4, 44.0), Vector3(0.0, 3.4, 0.0), ceil_mat))
	parent.add_child(_box(Vector3(0.4, 3.6, 44.0), Vector3(-10.0, 1.6, 0.0), stone))
	parent.add_child(_box(Vector3(0.4, 3.6, 44.0), Vector3(10.0, 1.6, 0.0), stone))
	parent.add_child(_box(Vector3(20.0, 3.6, 0.4), Vector3(0.0, 1.6, -22.0), stone))
	parent.add_child(_box(Vector3(20.0, 3.6, 0.4), Vector3(0.0, 1.6, 22.0), stone))

	# 掩体柱：给玩家绕行空间，也让丧尸分离力有可视参照
	var pillars: Array[Vector3] = [
		Vector3(-5.0, 1.6, -10.0), Vector3(5.0, 1.6, -10.0),
		Vector3(-5.0, 1.6, 6.0), Vector3(5.0, 1.6, 6.0),
		Vector3(-6.0, 1.6, -2.0), Vector3(6.0, 1.6, -2.0),
	]
	for p: Vector3 in pillars:
		parent.add_child(_box(Vector3(1.4, 3.2, 1.4), p, stone))

func _build_main() -> void:
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/level/level.gd"))

	# World 留空：几何 / 灯光 / 天空全部由 Level._load_chapter 在运行时按章构建。
	# 不再把 20x44 走廊烘进 main.tscn —— 那是章节系统之前的临时几何，留着只会
	# 在每章开场先闪一帧错误的墙，并且让主场景体积与审阅成本翻倍。
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)

	var player: Node = (load(SCENES + "player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector3(0.0, 0.05, 14.0)
	root.add_child(player)

	var spawner: Node = (load(SCENES + "wave_spawner.tscn") as PackedScene).instantiate()
	spawner.name = "WaveSpawner"
	# waves 由 Level._load_chapter 按章生成，这里不再预载 data/wave_*.tres
	root.add_child(spawner)

	var director: Node = (load(SCENES + "director.tscn") as PackedScene).instantiate()
	director.name = "Director"
	root.add_child(director)

	# 后期：低分量化 + CRT。layer 1 在 3D 之上、HUD(layer 2) 之下
	var fx := CanvasLayer.new()
	fx.name = "PostFX"
	fx.layer = 1
	var rect := ColorRect.new()
	rect.name = "PixelPost"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/pixelzombie_postprocess.gdshader")
	pm.set_shader_parameter(&"pixel_size", 1.0)
	# 亮度参数必须显式写死：着色器默认值（vignette 0.35 + scanline 0.18 +
	# saturation 0.85）叠加后把实测平均亮度压到 6/255，灰盒完全看不清。
	pm.set_shader_parameter(&"brightness", 1.16)
	pm.set_shader_parameter(&"lift", 0.035)
	pm.set_shader_parameter(&"contrast", 1.02)
	pm.set_shader_parameter(&"saturation", 1.0)
	pm.set_shader_parameter(&"vignette_strength", 0.20)
	pm.set_shader_parameter(&"scanline_strength", 0.10)
	rect.material = pm
	fx.add_child(rect)
	root.add_child(fx)

	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.set_script(load("res://scripts/ui/hud.gd"))
	root.add_child(hud)

	_pack(root, SCENES + "main.tscn")

# ── 序列化与工程设置 ────────────────────────────────────────────

func _pack(root: Node, path: String) -> void:
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack 失败 %s err=%d" % [path, err])
		root.free()
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("保存失败 %s err=%d" % [path, err])
	else:
		print("[build_world] wrote ", path)
	root.free()

func _set_owner(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner(child, owner)

func _apply_project_settings() -> void:
	# 完整键名是 application/run/main_scene，写成 run/main_scene 会被落到 [run] 段，
	# 引擎读不到主场景，启动直接报 "no main scene defined in the project"。
	ProjectSettings.set_setting("application/run/main_scene", SCENES + "main.tscn")
	ProjectSettings.set_setting("display/window/size/viewport_width", 480)
	ProjectSettings.set_setting("display/window/size/viewport_height", 270)
	ProjectSettings.set_setting("display/window/size/window_width_override", 1440)
	ProjectSettings.set_setting("display/window/size/window_height_override", 810)
	ProjectSettings.set_setting("display/window/stretch/mode", "viewport")
	ProjectSettings.set_setting("display/window/stretch/aspect", "keep")
	ProjectSettings.set_setting("display/window/stretch/scale_mode", "integer")
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)
	var names := ["World", "Player", "Zombie", "Weakspot", "Projectile", "Interact"]
	for i: int in names.size():
		ProjectSettings.set_setting("layer_names/3d_physics/layer_%d" % (i + 1), names[i])
	var err := ProjectSettings.save()
	if err != OK:
		push_error("ProjectSettings.save 失败 err=%d" % err)
	else:
		print("[build_world] project.godot saved")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENES))
	_build_zombie("zombie_fodder.tscn", SPR + "zombie_fodder.png", 2.4, 100.0, 12.0, 1.8)
	_build_zombie("zombie_charger.tscn", SPR + "zombie_charger.png", 4.1, 70.0, 14.0, 1.75)
	_build_zombie("zombie_bomber.tscn", SPR + "zombie_bomber.png", 1.8, 160.0, 22.0, 1.9)
	_build_zombie("zombie_screamer.tscn", SPR + "zombie_screamer.png", 2.9, 60.0, 8.0, 1.7)
	_build_player()
	_build_spawner()
	_build_director()
	_build_waves()
	_build_main()
	_apply_project_settings()
	print("[build_world] done")
	get_tree().quit()
