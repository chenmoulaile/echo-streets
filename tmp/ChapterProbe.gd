## 章节取证器：把每章几何建到空场景里，用固定机位抓图，验证材质/烘焙/构图。
## 不依赖 main.tscn —— 章节还没接进主场景时也能独立审图。
## 必须带窗口跑（--headless 下 viewport 纹理读不到）:
##   Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/chapter_runner.tscn
## 章节列表来自 scripts/level/chapters.gd，加一章这里不用改。
## 挂 PostFX：早前版本没有这一层，导致所有 with_post 参数从未被验证过
## （改 brightness/contrast 后截帧 lum/sd 一个数字都没变）。玩家看到的是
## 过完 pixelzombie_postprocess 的画面，探针不挂后期就等于在看半成品。
extends Node

const OUT_DIR := "res://tmp/shots/chapter/"
const POST_SHADER := "res://shaders/pixelzombie_postprocess.gdshader"

var _cam: Camera3D
var _root: Node3D
var _env_node: WorldEnvironment
var _probe_env: Environment
var _postfx: CanvasLayer
var _post_rect: ColorRect

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_root = Node3D.new()
	_root.name = "ProbeRoot"
	add_child(_root)

	_env_node = WorldEnvironment.new()
	_probe_env = Environment.new()
	_probe_env.background_mode = Environment.BG_COLOR
	_probe_env.background_color = Color(0.05, 0.06, 0.08)
	_probe_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_env_node.environment = _probe_env
	add_child(_env_node)

	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.05
	_cam.far = 300.0
	add_child(_cam)

	_build_postfx()

	var registry: GDScript = load("res://scripts/level/chapters.gd")
	var total: int = registry.call("count")
	for i: int in total:
		await _probe(i, registry.call("script_path", i))

	print("[chapter_probe] done")
	get_tree().quit()

## 建后期层。layer=1 与 main.tscn 的 PostFX 一致；ColorRect 铺满全屏。
## 参数默认值取自 main.tscn，每章在 _probe 里按 data.post 覆盖。
func _build_postfx() -> void:
	_postfx = CanvasLayer.new()
	_postfx.name = "PostFX"
	_postfx.layer = 1
	add_child(_postfx)
	_post_rect = ColorRect.new()
	_post_rect.name = "PixelPost"
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(POST_SHADER)
	_post_rect.material = mat
	_postfx.add_child(_post_rect)

## 按章节声明的 post 字典覆盖着色器参数。
## 只覆盖字典里出现的键 —— 未声明的保持上一章的值会串味，
## 所以每次先把全部键复位到 main.tscn 的基线值。
func _apply_post(post: Dictionary) -> void:
	var mat := _post_rect.material as ShaderMaterial
	if mat == null:
		return
	# 基线 = main.tscn 里 PixelPost 的默认值。
	# 注意：这份基线必须覆盖 shader 的全部 uniform，不能只写 main.tscn 用过的那 7 个。
	# 依据（ch04 审核报告实测）：旧版只遍历 base 的 7 个键，章节 with_post 里新加的
	# palette_levels / dither_strength / curvature / chromatic_aberration 四个键
	# 从来没被写进 shader → 截帧一直跑在 shader 默认的 palette_levels=8.0、
	# dither_strength=1.0、curvature=0.06 上。后果是截帧里四边 7px 纯黑边框
	# （black=7.06%）与楼体 8 级量化条纹全是取证器伪影，不是玩家真实画面
	# （对照 level.gd 的 _apply_post 是遍历 overrides 全量应用的）。
	var base := {
		"pixel_size": 1.0, "brightness": 1.16, "contrast": 1.02,
		"saturation": 1.0, "lift": 0.035, "vignette_strength": 0.20,
		"scanline_strength": 0.10, "palette_levels": 8.0,
		"dither_strength": 1.0, "curvature": 0.06,
		"chromatic_aberration": 1.0,
	}
	# 先按基线全量复位，再按章节覆盖 —— 两个循环都要遍历完整键集，
	# 只遍历 base 会漏掉章节里比 base 多出来的键。
	for k: String in base.keys():
		mat.set_shader_parameter(StringName(k), float(base[k]))
	for k: String in post.keys():
		mat.set_shader_parameter(StringName(k), float(post[k]))

func _probe(index: int, path: String) -> void:
	# 清掉上一章的节点，避免两章几何叠在一起
	for c: Node in _root.get_children():
		c.queue_free()
	await get_tree().process_frame

	var key: String = "ch%02d" % (index + 1)
	var script: GDScript = load(path)
	var data: RefCounted = script.call("build")
	var errs: PackedStringArray = data.call("validate")
	if errs.is_empty():
		print("[%s] validate OK  kills=%d  geo=%d  lamps=%d  spawns=%d" % [
			key, data.call("total_kills"), data.get("geometry").size(),
			data.get("lamps").size(), data.get("spawn_points").size()])
	else:
		for m: String in errs:
			print("[%s] VALIDATE FAIL: %s" % [key, m])

	# 场景里只能有一个 WorldEnvironment 生效（Godot 取树中第一个）。
	# 章节带天空时必须先让探针自己的纯色环境退出，否则天空永远测不出来。
	# WorldEnvironment 不是 Node3D，没有 visible —— 只能把 environment 置 null 来禁用。
	var chapter_has_sky: bool = not String(data.get("sky_texture")).is_empty()
	_env_node.environment = null if chapter_has_sky else _probe_env

	var t0: int = Time.get_ticks_msec()
	var stats: Dictionary = load("res://scripts/level/chapter_builder.gd").call(
		"build", data, _root)
	# 天空必须在几何之后建：WorldEnvironment 是环境设置，不依赖节点顺序，
	# 但放在后面能确保 _root 已存在、且日志里先看到几何统计再看到天空状态。
	var has_sky: bool = load("res://scripts/level/chapter_builder.gd").call(
		"build_sky", data, _root)
	var ms: int = Time.get_ticks_msec() - t0
	print("[%s] build %s sky=%s  (%d ms)" % [key, str(stats), str(has_sky), ms])

	# 后期参数按章覆盖，必须在抓图之前
	_apply_post(data.get("post"))

	var start: Vector3 = data.get("player_start")
	var yaw: float = float(data.get("player_yaw"))
	# 注意必须 await：_shot 内含 await，不 await 的协程调用会立刻返回且一帧都不执行
	# 机位 1：玩家视角（站立高度 1.6 米）—— 这是玩家真正看到的画面
	await _shot("%s_00_player" % key, start + Vector3(0.0, 1.6, 0.0), yaw)
	# 机位 2：场地中央平视，检查地面 / 灯带 / 柱列排布
	await _shot("%s_01_center" % key, Vector3(0.0, 2.4, 0.0), 0.0)
	# 机位 3：远端回望，检查反方向的墙面与纵深
	await _shot("%s_02_back" % key, Vector3(0.0, 1.7, -14.0), 180.0)
	# 机位 4/5：从走道另一侧朝侧墙斜看，检查幕墙 / 店面 / 工位阵列的纵深。
	# 原版写死 (±7, 1.6, 2) yaw ∓70：距侧墙只有 4 米、距工位 1.6 米，
	#   ch02_04_left 实测整幅被左墙占满（墙 100%，工位只在画面底部露出一条边），
	#   审核据此判「读不出工位阵列」—— 那是机位问题，不是场景问题。
	# 现在站到走道对侧、近端，朝斜前 70 度看（yaw 0 朝 -Z，±70 各偏 70 度）：
	#   03_right 从 x=-2.5 看 +X 侧（ch02 的玻璃会议室、ch01 的售货机墙），
	#   04_left  从 x=+2.5 看 -X 侧（ch02 的两列工位、ch01 的幕墙）。
	# 到最远工位约 12 米，侧墙与阵列一起形成透视纵深。
	await _shot("%s_03_right" % key, Vector3(-2.5, 1.6, 6.0), -70.0)
	await _shot("%s_04_left" % key, Vector3(2.5, 1.6, 6.0), 70.0)
	# 机位 6：高处俯视，检查整体布局与地面标线。
	# 必须按层高与房间尺度自适应 —— 旧版写死 start + (0, 6.5, 6.0) / pitch -38，
	# 实测两章都拍到"墙外"：
	#   ch01 层高 3.6 → 相机在 y=8.1，天花上方 4.5 米，画面 15.62% 是背景色；
	#   ch03 层高 5.2、start z=15 → z=21，出南墙 3 米，ch03_05_top 有 62 行（22.9%）
	#   纯背景色；数学验证：pitch -38 + 半 fov 37.5 → 最近可见地面
	#   z = 21 − 6.5/tan(75.5°) = 19.35 > 18，整个房间根本不在视锥里。
	# 现在从 geometry 里取最高的朝下发光面（天花/灯头）作为层高上限，
	# 相机压在它下方 0.75 米，横向退到玩家出生点与房间中心的中点。
	var ceil_y: float = 3.6
	for g: Variant in data.geometry:
		var gd: Dictionary = g
		if String(gd.get("k", "")) == "panel" and String(gd.get("axis", "")) == "down":
			ceil_y = maxf(ceil_y, (gd["pos"] as Vector3).y)
	var cam_y: float = minf(ceil_y - 0.75, 4.9)
	var cam_z: float = start.z * 0.5
	await _shot("%s_05_top" % key, Vector3(start.x, cam_y, cam_z), yaw, -52.0)

## pitch_deg 为 0 时平视；负值向下看。俯视机位必须带 pitch，否则只拍到天花板。
func _shot(tag: String, pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0) -> void:
	_cam.global_position = pos
	_cam.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("[%s] capture NULL" % tag)
		return
	var out: String = OUT_DIR + tag + ".png"
	var err: int = img.save_png(out)
	print("[%s] %dx%d save=%d" % [tag, img.get_width(), img.get_height(), err])
