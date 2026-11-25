## 第四章：ROOFTOP DECK —— 天台停机坪（demo 终章）
## 挂载节点类型: 无（extends RefCounted，静态 build() 返回 ChapterData）
## 视觉目标（用户要求「照片级 + 现代风格 + 不灰暗」）:
##   水泥自流平 + 太阳能板阵列 + 玻璃栏板 + 四面落日天空，
##   这是「当代高层天台」的通用视觉语言。本章刻意做成开放空间：
##   前三章都是封闭盒子，终章把墙拆掉换成天空，画面立刻透气。
## 布局（30 宽 x 34 长，净高 6.0，四周无实墙只有玻璃栏板）:
##   - 地面水泥自流平，中轴一条黄色停机坪导视线
##   - 两侧各一排太阳能板（倾斜，用薄板 + 支架近似）
##   - 四角是空调机组（大块金属箱），既是掩体也是视觉重量
##   - 四面玻璃栏板外是天空（真 skybox，不是平面天空板）
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")
## 道具层（太阳能板 / 机组 / 栏板 / 高杆灯）。单向依赖：props 不反向引用本文件。
const P := preload("res://scripts/level/chapter_04_props.gd")

## 天台尺寸常量。改这里就能整体缩放，不用逐条改坐标。
const W := 30.0        # X 向宽度
const L := 34.0        # Z 向长度
const H := 6.0         # 净高（开放空间，实际无顶）
const HALF_W := 15.0
const HALF_L := 17.0
## 玻璃栏板高度（无碰撞，玩家不会掉下去 —— 地面本身就是完整一块）
const RAIL := 1.15

static func build() -> ChapterData:
	var d := ChapterData.make("chapter_04", "ROOFTOP DECK", "NEO-TOKYO · HELIPAD 48F")
	d.objective = "HOLD THE ROOFTOP"
	d.mesh_step = 1.0
	# 落日暖光。这是全 demo 最暖的一章，用来把前三章的冷白收尾成"黄昏"。
	# ambient_sky 0.50/0.46/0.42 → 0.62/0.57/0.52、ambient_ground 0.28/0.25/0.23 → 0.42/0.38/0.34：
	#   加太阳方向光时把 horizon_gain 归零了（1.55 会把垂直面 amb 顶到 0.994，
	#   (1-amb) 只剩 0.006，太阳项被完全吃掉）。但 horizon_gain 同时也是垂直面
	#   与地面的天光来源，一关就整章变灰 —— 实测分带 lum：
	#   sky 0.546 / horizon 0.400 / far 0.395 / near 0.353(sd 0.055)，
	#   全图 lum 0.442 跌破 0.45 红线，地面 sd 只有 0.055 读成一片灰浆。
	#   这里直接抬 ambient 补回那部分天光，让露天场景仍有明亮的黄昏底色。
	d.with_ambient(Color(0.62, 0.57, 0.52), Color(0.42, 0.38, 0.34))
	# 后期：本章有整面天空做背景，contrast 提到 1.12 才让云层有层次；
	# saturation 1.14 让落日橙不褪成土黄。
	# brightness 1.14 → 1.02、lift 0.045 → 0.020（审核实测修正）：
	#   1.14 + 0.045 把落日天空的 R 通道打到削顶 —— 实测天空区 (10,6)-(470,99)
	#   n=43334 里 R≥250 占 35.43%（G/B 各 0.00%，所以 Stats 的 white 读不出来），
	#   区均值 rgb(240,138,23)，而原始贴图同区只有 rgb(181,102,53) Rmax=239。
	#   橙天烧成一片纯色，云层细节全丢。降回 1.02 让 R 峰值落在 245 左右。
	d.with_post({
		"brightness": 1.02, "contrast": 1.12, "saturation": 1.14,
		"lift": 0.041, "vignette_strength": 0.15, "scanline_strength": 0.05,
		"palette_levels": 12.0, "dither_strength": 0.18,
		"curvature": 0.0, "chromatic_aberration": 0.35,
	})
	d.with_player(Vector3(0.0, 0.0, 12.0), 0.0)
	# 真 skybox：地平线压到 v=0.5，与地面 y=0 严格对齐。
	# 旋转 200 度让落日出现在玩家出生点正前方偏右 —— 出生时 yaw=0 朝 -Z，
	# 落日出现在 -Z 方向才能在开场第一帧就抓住眼睛。
	# sky_energy 1.05 → 0.92：配合 brightness 下调，避免天空整体过曝。
	# 第 4 参 sun=0.55 开启落日方向光（室内三章不传，保持 0）。
	d.with_sky("res://assets/textures/sky_rooftop_equirect.png", 200.0, 0.92, 0.55)

	_shell(d)
	# 道具层（板阵列 / 机组 / 栏板 / 高杆灯）拆到 chapter_04_props.gd，
	# 本文件只保留"空间骨架"（地面/标线/天空/后处理）。
	# 拆分动机：PDF 硬红线单文件 ≤ 300 行，补齐审核修正后本文件涨到 328 行。
	P.solar_rows(d)
	P.hvac(d)
	P.rails(d)
	P.ceiling_lights(d)
	_spawns(d)
	_waves(d)
	return d

## 地面 + 停机坪标线。没有实墙：四面全是玻璃栏板外接天空。
static func _shell(d: ChapterData) -> void:
	# 水泥自流平地面。
	# 关键实测：顶点色在 1.0 处硬截断，初版 ConcreteWall(#6C6C5F, 0.42) × tint 1.34
	#   实际只渲染成 0.42 的反照率（tint 超出 1.0 的部分全被丢弃），
	#   再乘地面 lit≈0.63 后只有 rgb(67) —— 读成"阴天停车场"。
	# 正解：WhiteWall_Dirty(#C0C0C0, 0.75) × tint 0.68 ≈ 反照率 0.51（水泥该有的中灰），
	#   且 tint 落在合法区间内、真实生效。
	# tint 0.68 → 0.80（ambient 调整后的二次标定）：
	#   抬 ambient 后地面带只回到 0.402，仍比天空 0.546 暗 26%，
	#   整片地面读成"阴天的水泥"而不是"黄昏被落日照亮的水泥"。
	#   0.80 使反照率到 0.60，地面带到 0.47 左右，与天空形成黄昏该有的明暗关系；
	#   实测 white=0.00%，离削顶还有余量。
	d.add(K.panel(Vector3(0.0, 0.0, 0.0), Vector2(W, L), "up", "WhiteWall_Dirty",
		Color(0.80, 0.79, 0.76)))
	# 水泥分块浇筑色差 + 伸缩缝（地面层次修正）。
	# 为什么必须加：单块 30x34 米面板整片铺同一种材质，顶点色插值出来
	#   `ch04_00_player` 地面带 `gsd` 只有 0.048（`05_top` 更低到 0.031），
	#   整片读成"均匀灰浆"，完全没有水泥该有的块感。
	# 真实水泥自流平是分仓浇筑的，每仓颜色略有差异、仓与仓之间有伸缩缝。
	# 做法：铺若干块微差色 patch（y=0.004，与地面 0.0 和标线 0.012 都拉开），
	#   再加横向伸缩缝（沿 X 方向铺，**不能沿 Z 铺** —— 沿视线轴的细长条
	#   过视点必然投影成贯穿竖线，中轴黄线已改成虚线才躲过这个坑）。
	for patch: Array in [
			[Vector3(-6.0, 0.004, -9.0), Vector2(13.0, 12.0), Color(0.86, 0.855, 0.84)],
			[Vector3(7.5, 0.004, -4.0), Vector2(12.0, 14.0), Color(0.74, 0.735, 0.72)],
			[Vector3(-4.0, 0.004, 6.5), Vector2(14.0, 11.0), Color(0.90, 0.895, 0.88)],
			[Vector3(8.0, 0.004, 9.0), Vector2(11.0, 12.0), Color(0.79, 0.785, 0.77)],
	]:
		d.add(K.panel(patch[0], patch[1], "up", "WhiteWall_Dirty", patch[2], 0.6))
	# 伸缩缝：横向（沿 X）四条，暗色窄条
	for jz: float in [-12.0, -4.0, 4.0, 12.0]:
		d.add(K.panel(Vector3(0.0, 0.006, jz), Vector2(W - 1.0, 0.10), "up",
			"WhiteWall_Dirty", Color(0.46, 0.455, 0.44), 0.5))
	# 停机坪标线：中轴黄线 + 两侧白色边线
	#
	# 黄线改虚线 + 变窄（审核实测修正）：
	#   ① 宽度 0.34 → 0.24：初版逐行量到 y=168 时 9px、y=240 时 23px，
	#      中心恒在 x=240.0~241.5 —— 又一条「沿视线轴过视点」的透视竖线。
	#   ② 改虚线：`WarningLine.png` 自带每 16~24px 一条 L≈0.35 的深灰横带
	#      （逐行实测 y=0 (255,239,0) L=0.883 / y=16 (99,97,99) L=0.383 /
	#        y=24 0.825 / y=40 0.371），是黄黑警示纹而不是停机坪虚线。
	#      整条铺过去在透视下读成"一条被压扁的警示胶带"。
	#      改成 1.4 米一段、间隔 0.6 米，每段自己内部仍是警示纹，但宏观是虚线。
	for i: int in 17:
		var seg_z: float = -16.0 + float(i) * 2.0
		d.add(K.panel(Vector3(0.0, 0.012, seg_z), Vector2(0.24, 1.4), "up",
			"WarningLine", Color(1.0, 1.0, 0.94), 0.5))
	for sx: float in [-1.0, 1.0]:
		d.add(K.panel(Vector3(sx * 5.0, 0.012, 0.0), Vector2(0.20, L), "up",
			"CeramicFloor_White", Color(1.0, 1.0, 1.0), 0.5))
	# 中央 H 形停机坪标识（三条白条拼出 H）
	#
	# 材质换 + 抬高（审核实测修正）：
	#   初版三条白条全在 y=0.014 同平面且相邻贴边相接（横条 x∈[-1.75,1.75]，
	#   竖条从 ±1.75 起），零深度分离 → 交接处 Z-fight；
	#   更严重的是 CeramicFloor_White 只有 rgb(197)，与地面 rgb(192) 几乎同色，
	#   实测 H 区 lum=0.530 反而比旁边地面 0.543 还暗 0.013，白像素逐行
	#   y=170:5 / y=171:34 / y=172:0 / y=175:24 / y=180..210 全 0 ——
	#   被 24 阶量化撕成横条纹，完全读不出"H"。
	#   改 WhiteCeiling_MetalEdge(rgb 223,224,224) 并抬到 0.020，
	#   与黄线（0.012）拉开 8mm，量化台阶不再把两者混成一色。
	d.add(K.panel(Vector3(-2.2, 0.020, -2.0), Vector2(0.9, 7.0), "up",
		"WhiteCeiling_MetalEdge", Color(1.0, 1.0, 1.0), 0.5))
	d.add(K.panel(Vector3(2.2, 0.020, -2.0), Vector2(0.9, 7.0), "up",
		"WhiteCeiling_MetalEdge", Color(1.0, 1.0, 1.0), 0.5))
	d.add(K.panel(Vector3(0.0, 0.020, -2.0), Vector2(3.5, 0.9), "up",
		"WhiteCeiling_MetalEdge", Color(1.0, 1.0, 1.0), 0.5))
	# 天空改用真 skybox（build() 里的 with_sky），这里不再放平面天空板。
	# 平面板的问题：抬头能看到板的顶边、板本身被顶点色烘焙等于给太阳打假光，
	# 且四面板的接缝在转角处对不齐。真 skybox 由 GPU 按视线方向采样，无边界。
	#
	# 天空补光只留 4 盏（不是初版的 22 盏）。
	# 依据（审核实测）：初版在 z 从 -14 到 14 每 7 米挂 4 盏、共 22 盏不可见天光灯，
	#   每盏 range 14~16 米覆盖整个天台，直接把地面烘到 mean 0.938，
	#   而 light_baker 的指数饱和在 0.94 以上全部压平 —— 四角高杆灯完全看不出光斑。
	#   现在只在地平线方向留 4 盏大范围弱光当"天光方向感"，
	#   主照明交给高杆灯（见 _ceiling_lights），地面才有明暗层次。
	#
	# energy 1.15 → 0.30、range 26 → 15（审核 P0-5 修正，决定性）：
	#   实测这 4 盏 1.15/26 把全场 lit 抬到 ≥0.750，而 _knee 在 0.78 以上才开始压缩，
	#   高杆灯只能把灯脚推到 0.999 → _knee=0.919，与 8 米外的 0.750 只差 0.169，
	#   乘地面反照率 0.512 后**最终差仅 0.086，低于可辨阈值**。
	#   实测环向 72 采样极差 0.036（完全平坦），灯脚 L=0.454 反而比 8 米外 0.568 更暗。
	#   降到 0.30/15 后灯脚与远处的 lit 差约 0.42，乘反照率后差 0.215，是现状的 4.9 倍。
	for sx: float in [-1.0, 1.0]:
		d.lamps.append(K.lamp(Vector3(sx * (HALF_W - 3.0), 4.0, -HALF_L + 2.0),
			Color(1.0, 0.84, 0.66), 0.30, 15.0, false))
		d.lamps.append(K.lamp(Vector3(sx * (HALF_W - 3.0), 4.0, HALF_L - 2.0),
			Color(1.0, 0.86, 0.70), 0.30, 15.0, false))


## 刷怪点：四角 + 两侧 + 远端。天台开阔，允许刷得远一点。
static func _spawns(d: ChapterData) -> void:
	d.add_spawns([
		Vector3(0.0, 0.0, -15.0), Vector3(-6.0, 0.0, -15.0), Vector3(6.0, 0.0, -15.0),
		Vector3(-13.5, 0.0, -10.0), Vector3(13.5, 0.0, -10.0),
		Vector3(-13.5, 0.0, -2.0), Vector3(13.5, 0.0, -2.0),
		Vector3(-13.5, 0.0, 6.0), Vector3(13.5, 0.0, 6.0),
		Vector3(-8.0, 0.0, 14.0), Vector3(8.0, 0.0, 14.0),
	])

## 五波。终章：同屏上限拉到 30，节奏最紧。
static func _waves(d: ChapterData) -> void:
	d.wave(16, 14, 0.96, 0.10, 1.06, 1.10, 3.0, 4.0)
	d.wave(20, 18, 0.84, 0.22, 1.12, 1.24, 2.5, 4.0)
	d.wave(26, 22, 0.72, 0.30, 1.18, 1.40, 2.5, 3.5)
	d.wave(30, 26, 0.62, 0.36, 1.24, 1.54, 2.5, 3.5)
	d.wave(40, 30, 0.50, 0.44, 1.32, 1.72, 2.0, 0.0)
