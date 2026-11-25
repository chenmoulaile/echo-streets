## 第一章：ECHO LOBBY —�?现代写字楼大�?## 挂载节点类型: 无（extends RefCounted，静�?build() 返回 ChapterData�?## 视觉目标（用户要求「照片级 + 现代风格 + 不灰暗」）:
##   白色抛光石材 + 深色石材腰线 + 玻璃幕墙 + 铝质吊顶灯带�?##   这是「当代企业总部大堂」的通用视觉语言，靠材质对比与光斑层次出画面�?##   而不是靠堆贴图细�?—�?参考项目那�?WhiteWall 本来就是低对比度纯色墙，
##   它的照片感来自「大面纯�?+ 局部高�?+ 干净接缝」�?## 布局�?2 �?x 46 �?x 3.6 高）:
##   - 中央�?6 米宽的通行动线，两侧各一�?1.1x1.1 方柱
##   - 左墙（x=-11）是玻璃幕墙，透过玻璃看到落日天空
##   - 右墙（x=+11）是白墙 + 自动售货�?+ 储物柜，形成"室内街景"
##   - 远端（z=-23）是前台与双开门，作为视觉焦点
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")

## 大厅尺寸常量。改这里就能整体缩放，不用逐条改坐标�?const W := 22.0        # X 向宽�?const L := 46.0        # Z 向长�?const H := 3.6         # 净�?const HALF_W := 11.0
const HALF_L := 23.0

static func build() -> ChapterData:
	var d := ChapterData.make("chapter_01", "ECHO LOBBY", "NEO-TOKYO · CORPORATE ATRIUM")
	d.objective = "CLEAR THE LOBBY"
	d.mesh_step = 1.0
	# 冷白环境光。数值经 tmp/lightscan_runner.tscn 参数扫描标定�?4/16 分）�?	# energy=3.2 / range=6.0 / amb=0.40 �?地板 0.916、两灯间 0.646、光斑对�?0.27�?	# 旧�?0.66 会让地板叠到 1.000 削顶，贴图细节全丢�?	d.with_ambient(Color(0.40, 0.41, 0.43), Color(0.20, 0.196, 0.192))
	# 后处理：亮度略提、对比略降，避免"阴间滤镜"（用户明确说不要太灰暗）
	d.with_post({
		"brightness": 1.18, "contrast": 1.06, "saturation": 1.12,
		"lift": 0.045, "vignette_strength": 0.14, "scanline_strength": 0.06,
	})
	d.with_player(Vector3(0.0, 0.0, 18.0), 0.0)

	_shell(d)
	_columns(d)
	_ceiling(d)
	_left_curtain(d)
	_right_wall(d)
	_reception(d)
	_spawns(d)
	_waves(d)
	return d

## 地面 / 天花 / 四面墙。用 panel 而不�?box�?## 站在房间内部�?box 的内表面是背面，会被 cull 掉变成透明的；
## panel 的法线朝内，才是"看得见的�?�?static func _shell(d: ChapterData) -> void:
	# 地面：白色抛光陶瓷，中间嵌一条深色导视带
	d.add(K.panel(Vector3(0.0, 0.0, 0.0), Vector2(W, L), "up", "CeramicFloor_White",
		Color(1.0, 1.0, 1.0)))
	# 中轴导视带：CeramicFloor_Gray 本身平均�?#7B7B7B，再�?0.78 tint 后实�?	# 渲染值只�?rgb(74,76,78) —�?在画面里读成"地板上一条黑�?而不是深色石材�?	# tint 提到 1.30 后回�?~rgb(120)，才�?深色抛光石材"该有的明度�?	d.add(K.panel(Vector3(0.0, 0.012, 0.0), Vector2(2.6, L), "up", "CeramicFloor_Gray",
		Color(1.30, 1.32, 1.36), 0.5))
	# 天花：白色铝�?	d.add(K.panel(Vector3(0.0, H, 0.0), Vector2(W, L), "down", "WhiteCeiling",
		Color(0.94, 0.95, 0.97)))
	# 四面�?	d.add(K.panel(Vector3(0.0, H * 0.5, -HALF_L), Vector2(W, H), "z+", "WhiteWall",
		Color(1.0, 1.0, 1.0)))
	d.add(K.panel(Vector3(0.0, H * 0.5, HALF_L), Vector2(W, H), "z-", "WhiteWall",
		Color(0.92, 0.93, 0.95)))
	d.add(K.panel(Vector3(HALF_W, H * 0.5, 0.0), Vector2(L, H), "x-", "WhiteWall",
		Color(0.97, 0.97, 0.98)))
	# 左墙留作幕墙，这里只�?0.9 米高的墙裙，上面全是玻璃
	d.add(K.panel(Vector3(-HALF_W, 0.45, 0.0), Vector2(L, 0.9), "x+", "WhiteWall_Bottom_Blue",
		Color(0.86, 0.90, 0.96)))

## 两排方柱。柱子是"照片�?的关键：它给出纵深节奏与光斑落点�?## 也让 46 米的长厅不至于一眼望到底的空旷�?static func _columns(d: ChapterData) -> void:
	var z: float = -18.0
	while z <= 18.0:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * 6.4
			# 柱身：白色石�?			d.add(K.box(Vector3(1.1, H, 1.1), Vector3(x, H * 0.5, z), "WhiteWall_Column",
				Color(1.0, 1.0, 1.0)))
			# 柱础：深色石材，给柱�?落地�?，否则像悬空的方�?			d.add(K.box(Vector3(1.3, 0.28, 1.3), Vector3(x, 0.14, z), "CeramicFloor_Gray",
				Color(0.62, 0.64, 0.68)))
			# 柱顶：一圈深色压条，与吊顶脱开
			d.add(K.box(Vector3(1.24, 0.12, 1.24), Vector3(x, H - 0.06, z),
				"MetalWall", Color(0.72, 0.74, 0.78)))
		z += 9.0

## 吊顶：灯�?+ 每盏灯登记一个构建期光源（不产生节点）�?## 灯带朝向 -Y，用 WhiteCeiling_MetalEdge 的亮�?tint 冒充自发光�?static func _ceiling(d: ChapterData) -> void:
	var z: float = -19.0
	while z <= 19.0:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * 3.0
			# 灯槽（深色铝框）
			d.add(K.box(Vector3(1.9, 0.09, 0.44), Vector3(x, H - 0.045, z),
				"MetalPlateWall", Color(0.58, 0.60, 0.64)))
			# 发光�?			d.add(K.panel(Vector3(x, H - 0.095, z), Vector2(1.7, 0.34), "down",
				"WhiteCeiling_MetalEdge", Color(1.0, 0.99, 0.94), 0.5, true, true))
			# 光源登记：暖�?4300K，energy 3.2 / range 6.0 由参数扫描得�?			# （tmp/lightscan_runner.tscn�?4/16 分：地板 0.916、两灯间 0.646�?			d.lamps.append(K.lamp(Vector3(x, H - 0.2, z),
				Color(1.0, 0.97, 0.90), 3.2, 6.0))
		z += 6.5
	# 中轴补一条长灯带，把视线引向远端前台
	# 灯槽 tint �?0.58 提到 1.15：MetalPlateWall 平均�?#959E9D 再乘 0.58 �?	# 实测渲染 rgb(64,68,72)，灯槽比发光面暗三个档，读成"顶上一道黑�?�?	# 铝型材灯槽应该是接近白铝的浅灰，靠发光面本身的亮度做对比�?	d.add(K.box(Vector3(0.5, 0.09, 30.0), Vector3(0.0, H - 0.045, 0.0),
		"MetalPlateWall", Color(1.15, 1.16, 1.18)))
	d.add(K.panel(Vector3(0.0, H - 0.095, 0.0), Vector2(0.34, 29.0), "down",
		"WhiteCeiling_MetalEdge", Color(1.0, 0.99, 0.95), 0.5, true, true))

## 左墙：整面玻璃幕�?+ 幕墙外的落日天空板�?## 天空必须放在玻璃**外面**（更远的 x），否则会被玻璃挡住看不见�?static func _left_curtain(d: ChapterData) -> void:
	# 幕墙：墙裙已�?_shell 铺好，这里只补玻璃与竖挺
	var z: float = -HALF_L
	var pane: float = 3.0
	while z < HALF_L - 0.01:
		var cz: float = z + pane * 0.5
		# 玻璃：alpha 0.22 无碰撞，透出后面的天�?		d.add(K.box(Vector3(0.06, H - 1.05, pane - 0.16),
			Vector3(-HALF_W, 0.9 + (H - 1.05) * 0.5, cz), "Glass",
			Color(0.82, 0.92, 1.0), false, 0.22))
		# 竖挺：铝型材，给幕墙分格
		d.add(K.box(Vector3(0.22, H - 0.9, 0.14), Vector3(-HALF_W, 0.9 + (H - 0.9) * 0.5, z),
			"MetalWall", Color(0.88, 0.90, 0.93)))
		z += pane
	# 顶部横梁
	d.add(K.box(Vector3(0.3, 0.22, L), Vector3(-HALF_W, H - 0.11, 0.0),
		"MetalWall", Color(0.86, 0.88, 0.92)))
	# 幕墙�?3 米处的天空板：朝 +X 面向室内�?	# tiled=false 是必须的 —�?天空是有构图的大图，平铺会变�?一排橙色方�?�?	d.add(K.panel(Vector3(-HALF_W - 3.0, H * 0.5, 0.0), Vector2(L + 8.0, H + 6.0), "x+",
		"SkyTexture_Sunset", Color(1.0, 0.96, 0.90), 2.0, false))
	# 天空板补光：模拟落日从左侧灌进来，给白墙一点暖侧光�?	# down_only=false —�?这是整面发光的天空，不是吸顶灯，它要照亮上下两侧�?	var z2: float = -18.0
	while z2 <= 18.0:
		d.lamps.append(K.lamp(Vector3(-HALF_W + 1.2, 2.2, z2),
			Color(1.0, 0.86, 0.68), 0.55, 12.0, false))
		z2 += 9.0

## 右墙：白�?+ 售货�?+ 储物�?+ 消防箱，做出"室内街景"的密度�?static func _right_wall(d: ChapterData) -> void:
	var z: float = -16.0
	# 自动售货机（两两一组，靠墙内凹 0.3 米）
	while z <= 12.0:
		d.add(K.box(Vector3(0.72, 1.95, 1.0), Vector3(HALF_W - 0.36, 0.975, z),
			"VendingMachine", Color(1.0, 1.0, 1.0)))
		# 机器自身的面板光，让它在暗部也能读出�?		d.lamps.append(K.lamp(Vector3(HALF_W - 0.9, 1.5, z),
			Color(0.72, 0.90, 1.0), 0.45, 4.0))
		z += 4.5
	# 储物柜一�?	var lz: float = 14.0
	while lz <= 20.0:
		d.add(K.box(Vector3(0.52, 2.05, 0.92), Vector3(HALF_W - 0.26, 1.025, lz),
			"Locker_DarkBlue", Color(1.0, 1.0, 1.0)))
		lz += 1.0
	# 踢脚线：深色，收住墙与地的交界，避免"墙插进地�?的塑料感
	d.add(K.box(Vector3(0.10, 0.14, L), Vector3(HALF_W - 0.05, 0.07, 0.0),
		"MetalWall", Color(0.48, 0.50, 0.54)))
	d.add(K.box(Vector3(W, 0.14, 0.10), Vector3(0.0, 0.07, -HALF_L + 0.05),
		"MetalWall", Color(0.48, 0.50, 0.54)))

## 远端前台：大厅的视觉焦点。一块深色石材台�?+ 背后发光 logo 墙�?static func _reception(d: ChapterData) -> void:
	var cz: float = -HALF_L + 1.6
	# 台体
	d.add(K.box(Vector3(7.0, 1.1, 0.9), Vector3(0.0, 0.55, cz),
		"CeramicFloor_Gray", Color(0.70, 0.72, 0.76)))
	# 台面：更亮的石材，边缘略挑出
	d.add(K.box(Vector3(7.3, 0.09, 1.05), Vector3(0.0, 1.145, cz),
		"CeramicFloor_White", Color(1.0, 1.0, 1.0)))
	# 背景发光墙（�?+Z�?	d.add(K.panel(Vector3(0.0, 2.1, -HALF_L + 0.09), Vector2(9.0, 2.2), "z+",
		"WhiteWall_Dirty", Color(0.90, 0.94, 1.0)))
	d.lamps.append(K.lamp(Vector3(0.0, 2.2, -HALF_L + 1.4),
		Color(0.62, 0.84, 1.0), 1.1, 8.0))
	# 双开门（纯装饰，�?ExitDoor 材质贴面�?	d.add(K.box(Vector3(3.2, 2.3, 0.12), Vector3(0.0, 1.15, -HALF_L + 0.16),
		"ExitDoor", Color(1.0, 1.0, 1.0)))

## 刷怪点：两�?+ 两侧柱间，距出生�?0,18) 全部 �?8 米�?static func _spawns(d: ChapterData) -> void:
	d.add_spawns([
		Vector3(0.0, 0.0, -19.0), Vector3(-4.0, 0.0, -19.0), Vector3(4.0, 0.0, -19.0),
		Vector3(0.0, 0.0, -12.0), Vector3(-8.5, 0.0, -12.0), Vector3(8.5, 0.0, -12.0),
		Vector3(-8.5, 0.0, -3.0), Vector3(8.5, 0.0, -3.0),
		Vector3(-8.5, 0.0, 6.0), Vector3(8.5, 0.0, 6.0),
		Vector3(-4.0, 0.0, 10.0), Vector3(4.0, 0.0, 10.0),
	])

## 五波，节奏从"稀疏试�?走到"贴脸压迫"�?static func _waves(d: ChapterData) -> void:
	d.wave(10, 8, 1.10, 0.00, 1.00, 1.00, 3.0, 4.0)
	d.wave(14, 12, 0.95, 0.12, 1.06, 1.12, 2.5, 4.0)
	d.wave(18, 16, 0.82, 0.20, 1.12, 1.24, 2.5, 3.5)
	d.wave(22, 20, 0.70, 0.28, 1.18, 1.36, 2.5, 3.5)
	d.wave(28, 24, 0.58, 0.36, 1.24, 1.50, 2.0, 0.0)
