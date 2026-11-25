## 用 Godot 本体渲染第一人称 viewmodel（真 3D 透视，避免手绘 2D 投影的方向错觉）。
## 输出：tmp/vmraw/{frame}.png（768x576，带 alpha），后续由 tmp/PixVm.py 降采样 + 量化。
## 运行：Godot_v4.7.2 --path D:\mygame tmp/vm_render.tscn（**不能带 --headless**，否则
##   get_image() 返回 null）。
##
## 构图铁律（来自 tmp/vm/Handgun__HandgunIdle.png 参考帧）：
##   枪管朝「上-左-前」、握把在下、前臂从右下角出画。用 Basis.looking_at 指定枪管方向，
##   不要用欧拉角硬试 —— 欧拉角三个轴互相耦合，改一个另一个就偏。
extends Node

const OUT := "res://tmp/vmraw/"
const RW := 768
const RH := 576
## 枪管在相机空间里的朝向（上-左-前）。前臂方向是它的反向 + 一点向下。
const BARREL := Vector3(-0.34, 0.46, -0.82)

const COL := {
	"steel": Color(0.40, 0.44, 0.52),
	"steel_hi": Color(0.66, 0.71, 0.80),
	"steel_dk": Color(0.20, 0.23, 0.30),
	"acc": Color(0.30, 0.78, 0.86),
	"acc_hi": Color(0.62, 0.95, 0.98),
	"skin": Color(0.87, 0.71, 0.59),
	"skin_hi": Color(0.97, 0.83, 0.71),
	"skin_dk": Color(0.68, 0.51, 0.40),
	"shirt": Color(0.91, 0.93, 0.97),
	"shirt_dk": Color(0.72, 0.76, 0.84),
	"blazer": Color(0.15, 0.19, 0.28),
	"blazer_hi": Color(0.24, 0.30, 0.42),
	"wood": Color(0.44, 0.29, 0.19),
	"wood_hi": Color(0.58, 0.40, 0.27),
	"bore": Color(0.04, 0.05, 0.07),
	"brass": Color(0.85, 0.67, 0.31),
}

var _vp: SubViewport
var _cam: Camera3D
var _gun: Node3D
var _slide: Node3D
var _mag: Node3D
var _pump: Node3D
var _shell: Node3D
var _muzzle_local := Vector3.ZERO


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_viewport()
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _build_viewport() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(RW, RH)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.66, 0.78)
	env.ambient_light_energy = 0.72
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.near = 0.02
	_cam.far = 8.0
	_cam.current = true
	_vp.add_child(_cam)

	_add_light(Vector3(-0.45, 0.85, 0.55), 1.55, Color(1.0, 0.97, 0.92))
	_add_light(Vector3(0.75, 0.15, -0.65), 0.50, Color(0.72, 0.82, 1.0))
	_add_light(Vector3(0.10, -0.90, -0.30), 0.26, Color(0.60, 0.66, 0.78))


func _add_light(dir: Vector3, energy: float, col: Color) -> void:
	var l := DirectionalLight3D.new()
	l.light_energy = energy
	l.light_color = col
	l.shadow_enabled = false
	l.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
	_vp.add_child(l)


func _mat(col: Color, rough := 0.62, metal := 0.15) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color,
		rot := Vector3.ZERO, rough := 0.62, metal := 0.15) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, rough, metal)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## 枪根：位置 + 用 basis 定枪管方向（-Z 是枪管朝前）
func _gun_root(pos: Vector3, barrel: Vector3) -> void:
	_gun = Node3D.new()
	_gun.position = pos
	_gun.basis = Basis.looking_at(barrel.normalized(), Vector3.UP)
	_vp.add_child(_gun)


func _pistol() -> void:
	_gun_root(Vector3(0.080, -0.068, -0.400), BARREL)
	_muzzle_local = Vector3(0.0, 0.0, -0.152)

	# 套筒（可后坐）
	_slide = Node3D.new()
	_gun.add_child(_slide)
	_box(_slide, Vector3(0.050, 0.052, 0.196), Vector3(0, 0.0, -0.052), COL["steel"], Vector3.ZERO, 0.42, 0.55)
	_box(_slide, Vector3(0.050, 0.013, 0.196), Vector3(0, 0.025, -0.052), COL["steel_hi"], Vector3.ZERO, 0.34, 0.60)
	_box(_slide, Vector3(0.021, 0.015, 0.190), Vector3(-0.015, 0.031, -0.052), COL["steel_hi"], Vector3.ZERO, 0.30, 0.65)
	_box(_slide, Vector3(0.014, 0.021, 0.011), Vector3(0, 0.035, -0.140), COL["steel_dk"])        # 准星
	_box(_slide, Vector3(0.042, 0.017, 0.011), Vector3(0, 0.035, 0.030), COL["steel_dk"])        # 照门
	_box(_slide, Vector3(0.037, 0.031, 0.005), Vector3(0, 0.0, -0.150), COL["bore"])             # 膛口
	_box(_slide, Vector3(0.031, 0.017, 0.052), Vector3(0.011, 0.027, -0.030), COL["steel_dk"])   # 抛壳口
	_box(_slide, Vector3(0.007, 0.031, 0.072), Vector3(-0.027, -0.004, -0.050), COL["acc"])      # 识别条
	_box(_slide, Vector3(0.004, 0.009, 0.030), Vector3(-0.028, 0.014, -0.100), COL["acc_hi"])
	for i in 6:
		_box(_slide, Vector3(0.005, 0.039, 0.006), Vector3(-0.027, -0.004, 0.012 + i * 0.008), COL["steel_dk"])

	# 机匣 / 导轨 / 护圈 / 扳机
	_box(_gun, Vector3(0.047, 0.033, 0.132), Vector3(0, -0.041, -0.020), COL["steel_dk"], Vector3.ZERO, 0.55, 0.35)
	_box(_gun, Vector3(0.023, 0.011, 0.072), Vector3(0, -0.059, -0.055), COL["steel_dk"])
	_box(_gun, Vector3(0.031, 0.011, 0.060), Vector3(0, -0.073, -0.028), COL["steel_dk"])
	_box(_gun, Vector3(0.031, 0.041, 0.011), Vector3(0, -0.093, 0.000), COL["steel_dk"])
	_box(_gun, Vector3(0.031, 0.041, 0.011), Vector3(0, -0.093, -0.057), COL["steel_dk"])
	_box(_gun, Vector3(0.009, 0.027, 0.009), Vector3(0, -0.091, -0.030), COL["steel_hi"])       # 扳机

	# 握把 + 底板
	_box(_gun, Vector3(0.043, 0.124, 0.057), Vector3(0, -0.109, 0.030), COL["steel_dk"],
		Vector3(-13.0, 0, 0), 0.72, 0.10)
	_box(_gun, Vector3(0.045, 0.013, 0.059), Vector3(0, -0.167, 0.043), COL["steel"], Vector3(-13.0, 0, 0))
	_box(_gun, Vector3(0.047, 0.009, 0.031), Vector3(0, -0.172, 0.040), COL["acc"], Vector3(-13.0, 0, 0))

	_mag = Node3D.new()
	_gun.add_child(_mag)
	_box(_mag, Vector3(0.035, 0.101, 0.047), Vector3(0, -0.109, 0.030), COL["steel"],
		Vector3(-13.0, 0, 0), 0.50, 0.45)

	_shell = Node3D.new()
	_gun.add_child(_shell)
	_box(_shell, Vector3(0.013, 0.013, 0.031), Vector3(0.047, 0.031, -0.010), COL["brass"],
		Vector3(0, 0, 35.0), 0.30, 0.85)

	_hand_pistol()


## 主角是「默认学生」：裸手 + 白衬衫袖口 + 深藏青外套，不戴战术手套。
## 右手正拳握持的物理结构（枪局部系：-z 是枪管方向，+z 指向射手）：
##   握把占 z ∈ [0.0015, 0.0585]。掌心/掌根贴在握把**后方**（+z），
##   四指从后方绕过握把前缘（z≈0）卷回来，指尖落在近侧（-x）；
##   拇指压在近侧机匣上朝枪口伸。别把掌心放到 -x 侧 —— 那是拇指的位置，
##   放过去手就会从握把左边飘出去。
func _hand_pistol() -> void:
	var tilt := Vector3(-13.0, 0.0, 0.0)

	# 掌根 + 手背（贴握把后方）
	_box(_gun, Vector3(0.044, 0.092, 0.034), Vector3(-0.014, -0.118, 0.076), COL["skin"], tilt, 0.72, 0.0)
	_box(_gun, Vector3(0.038, 0.040, 0.030), Vector3(-0.016, -0.158, 0.082), COL["skin_dk"], tilt, 0.74, 0.0)
	# 近侧掌缘（拇指根），把掌心到拇指过渡出来
	_box(_gun, Vector3(0.022, 0.076, 0.062), Vector3(-0.036, -0.108, 0.048), COL["skin_dk"], tilt, 0.74, 0.0)

	# 四指从后方绕过前缘：每指两段（掌段 + 卷回的指尖段）
	for i in 4:
		var fy := -0.082 - i * 0.023
		var tuck := 1.0 - i * 0.09
		# 掌段：沿 -z 从握把后方包到前缘
		_box(_gun, Vector3(0.026 * tuck, 0.018, 0.070), Vector3(-0.008, fy, 0.030), COL["skin"], tilt, 0.72, 0.0)
		# 指缝
		_box(_gun, Vector3(0.024 * tuck, 0.004, 0.068), Vector3(-0.008, fy + 0.011, 0.030), COL["skin_dk"], tilt, 0.76, 0.0)
		# 指尖段：卷回近侧
		_box(_gun, Vector3(0.030 * tuck, 0.017, 0.022), Vector3(-0.020, fy, -0.001), COL["skin_hi"], tilt, 0.68, 0.0)

	# 拇指压在近侧机匣、朝枪口伸
	_box(_gun, Vector3(0.021, 0.024, 0.064), Vector3(-0.032, -0.055, -0.022), COL["skin"], Vector3.ZERO, 0.72, 0.0)
	_box(_gun, Vector3(0.019, 0.019, 0.026), Vector3(-0.034, -0.053, -0.064), COL["skin_hi"], Vector3.ZERO, 0.68, 0.0)
	_box(_gun, Vector3(0.012, 0.016, 0.022), Vector3(-0.033, -0.066, -0.006), COL["skin_dk"], Vector3.ZERO, 0.76, 0.0)

	_forearm(Vector3(-0.020, -0.176, 0.098), Vector3(-38.0, 10.0, 6.0))


## 手腕皮肤 → 白衬衫袖口（一圈）→ 深藏青外套前臂
func _forearm(wrist: Vector3, wrist_rot: Vector3) -> void:
	_box(_gun, Vector3(0.049, 0.052, 0.054), wrist, COL["skin_dk"], wrist_rot, 0.74, 0.0)
	_box(_gun, Vector3(0.074, 0.074, 0.050), wrist + Vector3(-0.010, -0.028, 0.026), COL["shirt"],
		Vector3(-52.0, 18.0, 8.0), 0.90, 0.0)
	_box(_gun, Vector3(0.079, 0.021, 0.048), wrist + Vector3(-0.010, -0.022, 0.020), COL["shirt_dk"],
		Vector3(-52.0, 18.0, 8.0), 0.92, 0.0)
	_box(_gun, Vector3(0.092, 0.092, 0.340), wrist + Vector3(-0.062, -0.140, 0.150), COL["blazer"],
		Vector3(-38.0, 22.0, 10.0), 0.94, 0.0)
	_box(_gun, Vector3(0.074, 0.033, 0.330), wrist + Vector3(-0.092, -0.108, 0.146), COL["blazer_hi"],
		Vector3(-38.0, 22.0, 10.0), 0.94, 0.0)


func _shotgun() -> void:
	_gun_root(Vector3(0.048, -0.122, -0.300), BARREL)
	_muzzle_local = Vector3(0.0, 0.012, -0.222)

	_box(_gun, Vector3(0.041, 0.027, 0.242), Vector3(0, 0.012, -0.100), COL["steel"], Vector3.ZERO, 0.40, 0.55)
	_box(_gun, Vector3(0.043, 0.011, 0.242), Vector3(0, 0.029, -0.100), COL["steel_hi"], Vector3.ZERO, 0.34, 0.60)
	_box(_gun, Vector3(0.031, 0.029, 0.005), Vector3(0, 0.012, -0.222), COL["bore"])
	_box(_gun, Vector3(0.033, 0.025, 0.182), Vector3(0, -0.019, -0.070), COL["steel_dk"])       # 弹仓管

	_pump = Node3D.new()
	_gun.add_child(_pump)
	_box(_pump, Vector3(0.053, 0.041, 0.092), Vector3(0, -0.007, -0.120), COL["wood"], Vector3.ZERO, 0.78, 0.0)
	for i in 5:
		_box(_pump, Vector3(0.055, 0.045, 0.007), Vector3(0, -0.007, -0.152 + i * 0.016), COL["wood_hi"],
			Vector3.ZERO, 0.80, 0.0)

	_box(_gun, Vector3(0.051, 0.063, 0.122), Vector3(0, -0.021, 0.020), COL["steel_dk"], Vector3.ZERO, 0.52, 0.40)
	_box(_gun, Vector3(0.021, 0.017, 0.031), Vector3(0, -0.021, 0.070), COL["bore"])            # 抛壳口
	_box(_gun, Vector3(0.007, 0.041, 0.062), Vector3(-0.027, -0.031, 0.010), COL["acc"])
	_box(_gun, Vector3(0.031, 0.013, 0.053), Vector3(0, -0.063, 0.010), COL["steel_dk"])
	_box(_gun, Vector3(0.031, 0.037, 0.011), Vector3(0, -0.081, 0.036), COL["steel_dk"])
	_box(_gun, Vector3(0.031, 0.037, 0.011), Vector3(0, -0.081, -0.016), COL["steel_dk"])
	_box(_gun, Vector3(0.009, 0.025, 0.009), Vector3(0, -0.079, 0.008), COL["steel_hi"])

	# 枪托
	_box(_gun, Vector3(0.047, 0.101, 0.071), Vector3(0, -0.121, 0.070), COL["wood"],
		Vector3(-14.0, 0, 0), 0.80, 0.0)
	_box(_gun, Vector3(0.049, 0.091, 0.057), Vector3(0, -0.201, 0.104), COL["wood_hi"],
		Vector3(-26.0, 0, 0), 0.80, 0.0)

	_shell = Node3D.new()
	_gun.add_child(_shell)
	_box(_shell, Vector3(0.015, 0.015, 0.035), Vector3(0.049, 0.000, 0.030), COL["brass"],
		Vector3(0, 0, 30.0), 0.30, 0.85)

	_mag = Node3D.new()   # 霰弹枪没有可落弹匣，占位保持接口一致
	_gun.add_child(_mag)

	_hand_shotgun()


func _hand_shotgun() -> void:
	var tilt := Vector3(-14.0, 0.0, 0.0)

	# 后手（握把）
	_box(_gun, Vector3(0.031, 0.087, 0.059), Vector3(-0.043, -0.113, 0.056), COL["skin"], tilt, 0.72, 0.0)
	_box(_gun, Vector3(0.035, 0.040, 0.049), Vector3(-0.045, -0.150, 0.064), COL["skin_dk"], tilt, 0.74, 0.0)
	_box(_gun, Vector3(0.029, 0.026, 0.067), Vector3(-0.041, -0.074, 0.036), COL["skin_hi"], tilt, 0.66, 0.0)
	for i in 3:
		var fy := -0.087 - i * 0.027
		_box(_gun, Vector3(0.051, 0.018, 0.025), Vector3(-0.017, fy, 0.030), COL["skin"], tilt, 0.72, 0.0)
		_box(_gun, Vector3(0.049, 0.004, 0.027), Vector3(-0.017, fy + 0.012, 0.030), COL["skin_dk"], tilt, 0.76, 0.0)
		_box(_gun, Vector3(0.016, 0.018, 0.023), Vector3(-0.044, fy, 0.032), COL["skin_hi"], tilt, 0.68, 0.0)
	_forearm(Vector3(-0.049, -0.180, 0.104), Vector3(-40.0, 8.0, 4.0))

	# 前手托住护木：整只手包住护木，只画手背 + 三道指缝，不画指节
	_box(_gun, Vector3(0.056, 0.036, 0.102), Vector3(-0.021, -0.041, -0.120), COL["skin"], Vector3.ZERO, 0.72, 0.0)
	_box(_gun, Vector3(0.058, 0.010, 0.104), Vector3(-0.021, -0.025, -0.120), COL["skin_hi"], Vector3.ZERO, 0.66, 0.0)
	for i in 3:
		_box(_gun, Vector3(0.059, 0.032, 0.005), Vector3(-0.021, -0.041, -0.152 + i * 0.030), COL["skin_dk"],
			Vector3.ZERO, 0.76, 0.0)
	_box(_gun, Vector3(0.020, 0.030, 0.056), Vector3(-0.048, -0.046, -0.118), COL["skin_dk"], Vector3.ZERO, 0.74, 0.0)
	_box(_gun, Vector3(0.052, 0.052, 0.050), Vector3(-0.062, -0.074, -0.108), COL["shirt"],
		Vector3(-40.0, -14.0, 0.0), 0.90, 0.0)
	_box(_gun, Vector3(0.064, 0.064, 0.250), Vector3(-0.124, -0.186, -0.010), COL["blazer"],
		Vector3(-30.0, -26.0, 0.0), 0.94, 0.0)
	_box(_gun, Vector3(0.050, 0.026, 0.244), Vector3(-0.150, -0.158, -0.014), COL["blazer_hi"],
		Vector3(-30.0, -26.0, 0.0), 0.94, 0.0)


func _pose(p: Dictionary) -> void:
	var kick: float = p.get("kick", 0.0)
	var base := _gun.position
	_gun.rotation_degrees = Vector3.ZERO
	_gun.basis = Basis.looking_at(BARREL.normalized(), Vector3.UP)
	_gun.rotate_object_local(Vector3.RIGHT, deg_to_rad(-kick))
	_gun.position = base + Vector3(0, -kick * 0.0016, 0) + Vector3(0, float(p.get("dy", 0.0)), 0)
	if p.has("slide"):
		_slide.position.z = float(p["slide"])
	if p.has("pump") and _pump != null:
		_pump.position.z = float(p["pump"])
	_mag.visible = float(p.get("mag_drop", 0.0)) > 0.0005
	_mag.position = Vector3(0, -float(p.get("mag_drop", 0.0)) * 3.2, -float(p.get("mag_drop", 0.0)) * 1.2)
	_shell.visible = bool(p.get("shell", false))


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img == null:
		push_error("[vm] 截帧为空: %s" % file_name)
		return
	var path := ProjectSettings.globalize_path(OUT + file_name + ".png")
	var err := img.save_png(path)
	# 打印 alpha 包围盒 + 枪口屏幕坐标，用来定 PixVm 的固定裁剪窗口
	var bb := img.get_region(Rect2i(0, 0, RW, RH)).get_used_rect()
	var mp := _cam.unproject_position(_gun.to_global(_muzzle_local))
	print("  %-18s save=%d bbox=(%d,%d,%d,%d) muzzle=(%.1f,%.1f)" % [
		file_name, err, bb.position.x, bb.position.y, bb.size.x, bb.size.y, mp.x, mp.y])


func _run() -> void:
	print("=== VM RENDER ===")
	_pistol()
	var pistol := [
		["pistol_idle", {}],
		["pistol_dry", {"slide": 0.026}],
		["pistol_fire1", {"slide": 0.030, "kick": 6.0, "shell": true}],
		["pistol_fire2", {"slide": 0.016, "kick": 2.6}],
		["pistol_fire3", {"slide": 0.0, "kick": 0.0}],
		["pistol_reload1", {"slide": 0.026, "mag_drop": 0.055}],
		["pistol_reload2", {"slide": 0.026, "dy": -0.006}],
		["pistol_reload3", {"slide": 0.026, "dy": 0.008}],
		["pistol_reload4", {"slide": 0.0, "dy": 0.0}],
		["pistol_draw", {"dy": -0.075, "kick": -14.0}],
	]
	for entry in pistol:
		_pose(entry[1])
		await _shot(entry[0])
	_gun.queue_free()
	await get_tree().process_frame

	_shotgun()
	var shell := [
		["shotgun_idle", {}],
		["shotgun_fire1", {"kick": 7.0, "shell": true}],
		["shotgun_fire2", {"kick": 5.0}],
		["shotgun_fire3", {"kick": 3.2}],
		["shotgun_fire4", {"kick": 1.4}],
		["shotgun_fire5", {"kick": 0.0}],
		["shotgun_reload1", {"pump": 0.030, "kick": 1.5}],
		["shotgun_reload2", {"pump": 0.0, "kick": 0.0}],
		["shotgun_draw", {"dy": -0.075, "kick": -14.0}],
		["shotgun_altfire", {"kick": 1.0}],
	]
	for entry in shell:
		_pose(entry[1])
		await _shot(entry[0])
	print("=== VM RENDER DONE ===")
