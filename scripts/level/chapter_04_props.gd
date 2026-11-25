## 第四章道具层：太阳能板阵列 / 空调机组 / 玻璃栏板 / 高杆灯。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   chapter_04_rooftop.gd 在补齐审核修正后涨到 328 行，超红线。
##   本章的"道具"与"空间骨架"是两个独立关注点：
##   骨架（地面/标线/天空/后处理）决定"这是个什么空间"，
##   道具（板阵列/机组/栏板/灯）决定"这个空间里放了什么"。
##   拆开后骨架层 180 行、道具层 150 行，两边都能继续长注释而不撞线。
## 依赖: 只 preload chapter_kit（几何原语），不反向依赖 rooftop（避免循环引用）。
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")

## 与 chapter_04_rooftop.gd 保持一致的尺寸常量。
## 这里重复声明而不是引用 rooftop，是因为 rooftop 会 preload 本文件，
## 反向引用会形成 Cyclic reference（Godot 直接报错）。
const W := 30.0
const L := 34.0
const HALF_W := 15.0
const HALF_L := 17.0
const RAIL := 1.15

## 太阳能板倾角（度）与正切。板面朝 +Z 抬高 12°，与真实屋顶光伏一致。
const PANEL_TILT := 12.0
const PANEL_TAN := 0.21256

## 两排太阳能板。**真倾斜**（rot.x = 12°），不再靠"前矮柱后高柱"假装。
##
## 三次修正（全部来自审核实测）：
##   ① 初版后立柱高 1.15、中心 0.575 → 柱顶 1.15，而板底只有 0.83，
##      四根黑柱从板面穿出 0.26 米，一眼看出是假倾斜。
##   ② 第二版把后柱压到 0.82、前柱 0.68，但板本身是水平薄板 ——
##      审核逐列扫板顶边（ch04_03_right）：x=100 时 y=140、x=300 时 y=146，
##      **跨 200px 只升 6px**，而 12° 真倾斜在这个投影下应有 ≥20px 斜差。
##      且前柱顶 0.68 与板框底 0.76 之间留着 0.08 米空隙（柱子没顶到板），
##      后柱顶 0.82 与板框顶 0.82 完全共面 → Z-fight。
##   ③ 现在真的旋转网格。柱高按 tan(12°)=0.2126 反解，
##      柱顶严格落在板框底面下 2~3mm（不穿模、不留缝）。
##
## 组数 6 → 7（审核 P2）：`while z <= 13.0` 步 4.4 只排出 6 组，
##   北端空档 6.59 米、南端 2.59 米，阵列明显偏南。改 7 组、步长 4.0。
static func solar_rows(d: ChapterData) -> void:
	# x 从 ±10.5 收到 ±10.2：给机组留出 0.37 米间隙（见 hvac 的注释）
	var x_off: float = 10.2
	var frame_h: float = 0.06
	var face_h: float = 0.05
	var frame_y: float = 0.73
	var face_y: float = 0.80
	# 板框底面在柱位处的世界高度：中心线高度 - 半厚/cos(倾角)
	var half_t: float = frame_h * 0.5 / cos(deg_to_rad(PANEL_TILT))
	for i: int in 7:
		var z: float = -11.4 + float(i) * 4.0
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * x_off
			# 后立柱（-Z 侧，板面抬高的一侧）
			var rear_top: float = frame_y + 1.05 * PANEL_TAN - half_t - 0.003
			d.add(K.box(Vector3(0.10, rear_top, 0.10),
				Vector3(x, rear_top * 0.5, z - 1.05),
				"MetalWall", Color(0.62, 0.64, 0.68)))
			# 前立柱（+Z 侧，朝玩家，板面压低的一侧）
			var front_top: float = frame_y - 1.05 * PANEL_TAN - half_t - 0.003
			d.add(K.box(Vector3(0.10, front_top, 0.10),
				Vector3(x, front_top * 0.5, z + 1.05),
				"MetalWall", Color(0.62, 0.64, 0.68)))
			# 板框：铝型材收边，比板面大一圈形成可见边框
			d.add(K.box(Vector3(2.46, frame_h, 2.66), Vector3(x, frame_y, z),
				"MetalWall", Color(0.80, 0.82, 0.86), true, 1.0, 0.0,
				Vector3(PANEL_TILT, 0.0, 0.0)))
			# 板面：深蓝光伏。与板框沿世界 Y 拉开 0.07，
			# 旋转后垂直间距 0.07*cos12=0.0685 > 半厚之和 0.055，不互相穿插。
			d.add(K.box(Vector3(2.42, face_h, 2.62), Vector3(x, face_y, z),
				"SolarPanel", Color(1.0, 1.0, 1.0), true, 1.0, 0.0,
				Vector3(PANEL_TILT, 0.0, 0.0)))

## 四角空调机组：大块金属箱。既是掩体（能绕后），也给天台"设备层"的重量。
##
## 位置与尺寸修正（审核 P0-2，实测 AABB 重叠 0.074 m³）：
##   初版机组中心 x=±12.4、尺寸 2.6 → x 从 ±11.10 起，
##   而太阳能板框中心 x=±10.5、尺寸 2.42 → x 到 ±11.71，
##   两者在 x 上重叠 0.61 米；z 上板到 -14.31、机组到 -14.50 也重叠。
##   实测重叠体积 0.074 m³（板面 0.064 m³），板面 y[0.83,0.89] 整段落在
##   机组 y[0,2.0] 内 —— 板从金属箱侧壁长出来。
##   现在机组外移到 ±13.3、尺寸缩到 2.3（x 从 ±12.15 起），
##   与板框最大 x=±11.43 之间留 0.72 米通道，既无穿模也能绕后。
static func hvac(d: ChapterData) -> void:
	var spots: Array = [
		[Vector3(-13.3, 0.0, -13.6), Vector3(2.3, 2.0, 2.2)],
		[Vector3(13.3, 0.0, -13.6), Vector3(2.3, 2.0, 2.2)],
		[Vector3(-13.3, 0.0, 13.6), Vector3(2.3, 2.0, 2.2)],
		[Vector3(13.3, 0.0, 13.6), Vector3(2.3, 2.0, 2.2)],
	]
	for s: Array in spots:
		var c: Vector3 = s[0]
		var sz: Vector3 = s[1]
		d.add(K.box(sz, c + Vector3(0.0, sz.y * 0.5, 0.0), "MetalPlateWall",
			Color(0.90, 0.91, 0.93)))
		# 顶面格栅：深色薄板，让机组顶部不是一块纯色
		d.add(K.box(Vector3(sz.x * 0.86, 0.06, sz.z * 0.86),
			c + Vector3(0.0, sz.y + 0.03, 0.0), "Vent", Color(0.70, 0.72, 0.76)))
		# 底部混凝土基座
		d.add(K.box(Vector3(sz.x + 0.30, 0.16, sz.z + 0.30),
			c + Vector3(0.0, 0.08, 0.0), "ConcreteWall", Color(0.96, 0.96, 0.94)))

## 玻璃栏板：四面一圈。无碰撞 —— 地面是完整一块，玩家撞不出去也不会掉。
## 扶手用不锈钢细方管，读得出"天台护栏"而不是透明玻璃。
##
## alpha 0.28 → 1.0（决定性修复，与 ch01/ch03 同一根因）：
##   chapter_builder._material 的 alpha 是「与贴图 alpha 相乘」。
##   tmp/TexAlpha 实测 Glass.png 的 alpha 中位数只有 26/255 = 0.102
##   （mean=33 p10=26 p50=26 p90=26 max=255 opaque=3.1%），
##   再乘 0.28 只剩 2.9% —— 玻璃在数学上等于不存在。
##   审核员实测 ch04_00 x=20 y=144..168 连续 25 行 L<20，
##   玻璃栏板读成"黑色实心矮墙"。传 1.0 后最终 0.102 才是真实玻璃。
##
## 补充（ch04 审核 P0-1 的真正根因）：光传 1.0 还不够 ——
##   chapter_builder 的判定是 `if alpha < 1.0`，传 1.0 时条件不成立，
##   材质走 TRANSPARENCY_DISABLED，**引擎完全忽略贴图 alpha**，
##   albedo 取平均色 #C3EFFC，渲染成不透明青白板（实测 y=138
##   rgb(187,234,249) L=0.883，比背后天空 0.651 亮 0.23）。
##   已在 chapter_builder._material 里改成 `if alpha < 1.0 or tex_has_alpha:`，
##   这里的 1.0 现在才真正生效。
static func rails(d: ChapterData) -> void:
	# 南北两条（沿 X）
	for sz: float in [-1.0, 1.0]:
		var z: float = sz * (HALF_L - 0.10)
		d.add(K.box(Vector3(W, RAIL, 0.08), Vector3(0.0, RAIL * 0.5, z), "Glass",
			Color(0.90, 0.95, 1.0), false, 1.0))
		d.add(K.box(Vector3(W, 0.08, 0.14), Vector3(0.0, RAIL + 0.04, z),
			"MetalWall", Color(0.94, 0.95, 0.97)))
		# 立柱：每 3 米一根
		var px: float = -HALF_W + 1.5
		while px <= HALF_W - 1.4:
			d.add(K.box(Vector3(0.09, RAIL, 0.13), Vector3(px, RAIL * 0.5, z),
				"MetalWall", Color(0.86, 0.88, 0.92)))
			px += 3.0
	# 东西两条（沿 Z）
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * (HALF_W - 0.10)
		d.add(K.box(Vector3(0.08, RAIL, L), Vector3(x, RAIL * 0.5, 0.0), "Glass",
			Color(0.90, 0.95, 1.0), false, 1.0))
		d.add(K.box(Vector3(0.14, 0.08, L), Vector3(x, RAIL + 0.04, 0.0),
			"MetalWall", Color(0.94, 0.95, 0.97)))
		var pz: float = -HALF_L + 1.5
		while pz <= HALF_L - 1.4:
			d.add(K.box(Vector3(0.13, RAIL, 0.09), Vector3(x, RAIL * 0.5, pz),
				"MetalWall", Color(0.86, 0.88, 0.92)))
			pz += 3.0

## 天台照明：四角高杆灯。这是本章的主光源。
##
## 三条修正（全部来自审核实测）：
##   ① energy 1.6 → 2.4、range 9 → 11：初版 22 盏天光灯把地面烘到 0.938，
##      高杆灯完全看不出光斑；删掉天光灯后必须把这 4 盏提到主光级别。
##   ② 灯杆顶 4.2 → 4.11：初版杆顶正好穿进灯头（灯头 4.11~4.29），
##      杆从灯头底面插进去，转角处看到一根金属棍穿过灯罩。
##   ③ 灯头改 emissive：不发光的面板会被顶点色烘焙成暗块，
##      读成"四个黑盒子挂在杆顶"而不是灯。
static func ceiling_lights(d: ChapterData) -> void:
	var spots: Array = [
		Vector3(-13.0, 4.2, -8.0), Vector3(13.0, 4.2, -8.0),
		Vector3(-13.0, 4.2, 8.0), Vector3(13.0, 4.2, 8.0),
	]
	for p: Vector3 in spots:
		# 灯杆：顶 4.11，正好顶到灯头底面，不穿进灯罩
		d.add(K.box(Vector3(0.14, 4.11, 0.14), Vector3(p.x, 2.055, p.z),
			"MetalWall", Color(0.58, 0.60, 0.64)))
		# 灯头外壳
		d.add(K.box(Vector3(0.46, 0.18, 0.46), Vector3(p.x, p.y, p.z),
			"MetalPlateWall", Color(0.82, 0.84, 0.88)))
		# 灯头底面发光面（朝下，emissive 不参与烘焙）
		d.add(K.panel(Vector3(p.x, p.y - 0.095, p.z), Vector2(0.38, 0.38),
			"down", "WhiteCeiling_MetalEdge", Color(1.0, 0.96, 0.86),
			0.25, true, true))
		d.lamps.append(K.lamp(Vector3(p.x, p.y - 0.15, p.z),
			Color(1.0, 0.94, 0.84), 2.4, 11.0))
