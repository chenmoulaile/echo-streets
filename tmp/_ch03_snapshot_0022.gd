## 第三章：MALL ATRIUM —— 现代商场中庭
## 挂载节点类型: 无（extends RefCounted，静态 build() 返回 ChapterData）
## 视觉目标（用户要求「照片级 + 现代风格 + 不灰暗」）:
##   蓝白泳池瓷砖 + 玻璃栏板挑空 + 店铺门面 + 双排吊顶筒灯，
##   这是「当代购物中心中庭」的通用视觉语言。本章是整个 demo 最亮的一章 ——
##   瓷砖反光 + 挑空进光，用来把前两章的"办公空间"节奏打断。
## 布局（26 宽 x 36 长 x 5.2 高，双层挑空）:
##   - 中央是 10 米宽的挑空（抬头看到二层环廊与天花）
##   - 二层环廊在 y=2.8，四周一圈玻璃栏板（纯装饰，玩家上不去）
##   - 两侧 x=±9 是店铺门面：玻璃橱窗 + 店招 + 门头灯
##   - 地面铺蓝白瓷砖，中间一条深色导视带
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")

## 中庭尺寸常量。改这里就能整体缩放，不用逐条改坐标。
const W := 26.0        # X 向宽度
const L := 36.0        # Z 向长度
const H := 5.2         # 净高（挑空中庭，比办公层高 2 米）
const HALF_W := 13.0
const HALF_L := 18.0
## 二层环廊标高（纯视觉，无碰撞）
const MEZZ := 2.8

static func build() -> ChapterData:
	var d := ChapterData.make("chapter_03", "MALL ATRIUM", "NEO-TOKYO · SKY MALL")
	d.objective = "CLEAR THE ATRIUM"
	d.mesh_step = 1.0
	# 冷白偏蓝的环境光：瓷砖是蓝白的，环境光带一点蓝才不会互相打架。
	d.with_ambient(Color(0.46, 0.48, 0.52), Color(0.26, 0.25, 0.24))
	# 后期：本章大面积浅色，brightness 1.20 会把瓷砖推到接近纯白，
	# 所以 contrast 保持 1.08、vignette 压到 0.13（不要暗角过重破坏通透感）。
	d.with_post({
		"brightness": 1.20, "contrast": 1.08, "saturation": 1.10,
		"lift": 0.042, "vignette_strength": 0.13, "scanline_strength": 0.05,
	})
	# 出生点必须离最近刷怪点 ≥ 6 米（ChapterData.validate 硬约束）。
	# (0,15) 到 (±5,10) 的距离是 7.07 —— 原值 (0,13) 只有 5.83，开局会被贴脸。
	d.with_player(Vector3(0.0, 0.0, 15.0), 0.0)

	_shell(d)
	_mezzanine(d)
	_shopfronts(d)
	_ceiling(d)
	_spawns(d)
	_waves(d)
	return d

## 地面 / 天花 / 四面墙。
static func _shell(d: ChapterData) -> void:
	# 蓝白瓷砖地面：本章的"亮"主要来自这块大面积浅色。
	# 不用 PoolTiles —— 它是 200px 的马赛克小砖（平均色 #487E9C），
	# 平铺在 26x36 米的大厅上每 0.2 米重复一次，远处叠成棋盘状摩尔纹，
	# 整片地面读成"噪点地毯"而不是瓷砖（实测 ch03_01_center.png）。
	# 改用 CeramicFloor_White #EBEAEB 打底，靠 tint 压出冷调，
	# 再用导视带与警戒线做动线，才是现代商场的地面语言。
	# tint 必须明显偏蓝（0.80/0.90/1.00）：中性白会和第一章的白石大堂撞车，
	# 四章需要各自的色彩身份 —— 本章的识别色就是「泳池蓝白」。
	d.add(K.panel(Vector3(0.0, 0.0, 0.0), Vector2(W, L), "up", "CeramicFloor_White",
		Color(0.80, 0.90, 1.00)))
	# 中轴深色导视带：给长厅一条视觉脊椎，否则一片蓝白没有透视参照。
	# 关键实测：顶点色在 1.0 处**硬截断**（ch01 判定性实验：同一材质 tint 1.06/1.42/1.72
	#   渲染值逐字节相同；tint(3.0,0,0) 渲染出 rgb(106,0,0) 才证明通道活着）。
	#   → 任何 >1.0 的 tint 都是死值，想比材质本身更亮只能换更亮的材质。
	# 正解：CeramicFloor_White(#EBEAEB) × tint 0.62 ≈ 反照率 0.57，
	#   与冷蓝地面 lit≈0.87 相乘得 rgb(122)，比值 0.60 —— 深石材而非黑洞。
	d.add(K.panel(Vector3(0.0, 0.012, 0.0), Vector2(3.0, L), "up", "CeramicFloor_White",
		Color(0.62, 0.66, 0.74), 0.5))
	# 导视带两侧的黄色警戒边线：商场施工/动线的通用视觉符号
	for sx: float in [-1.0, 1.0]:
		d.add(K.panel(Vector3(sx * 1.62, 0.014, 0.0), Vector2(0.16, L), "up",
			"WarningLine", Color(1.0, 1.0, 0.9), 1.0))
	# 天花
	d.add(K.panel(Vector3(0.0, H, 0.0), Vector2(W, L), "down", "WhiteCeiling",
		Color(0.94, 0.95, 0.97)))
	# 前后两面墙（z 方向）
	for sz: float in [-1.0, 1.0]:
		var axis: String = "z+" if sz < 0.0 else "z-"
		d.add(K.panel(Vector3(0.0, H * 0.5, sz * HALF_L), Vector2(W, H), axis,
			"WhiteWall", Color(0.98, 0.98, 1.0)))
	# 左右两面墙（x 方向）
	d.add(K.panel(Vector3(-HALF_W, H * 0.5, 0.0), Vector2(L, H), "x+", "WhiteWall",
		Color(0.96, 0.97, 0.99)))
	d.add(K.panel(Vector3(HALF_W, H * 0.5, 0.0), Vector2(L, H), "x-", "WhiteWall",
		Color(0.96, 0.97, 0.99)))
	# 墙裙：蓝瓷砖，高 1.1 米，与地面呼应
	for sx: float in [-1.0, 1.0]:
		d.add(K.panel(Vector3(sx * HALF_W, 0.55, 0.0), Vector2(L, 1.1),
			"x+" if sx < 0.0 else "x-", "PoolTiles", Color(0.86, 0.92, 1.0)))
	# 踢脚线
	d.add(K.box(Vector3(0.10, 0.10, L), Vector3(-HALF_W + 0.05, 0.05, 0.0),
		"MetalWall", Color(0.58, 0.60, 0.64)))
	d.add(K.box(Vector3(0.10, 0.10, L), Vector3(HALF_W - 0.05, 0.05, 0.0),
		"MetalWall", Color(0.58, 0.60, 0.64)))

## 二层环廊：一圈楼板 + 玻璃栏板 + 栏板扶手。
## 全部无碰撞（玩家上不去，也不需要挡子弹）—— 有碰撞会变成头顶的隐形天花板。
static func _mezzanine(d: ChapterData) -> void:
	# 环廊楼板：四条，围出中间 10x20 的挑空
	var band: float = 3.4
	# 沿 X 的两条（南北）
	for sz: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(W, 0.28, band),
			Vector3(0.0, MEZZ, sz * (HALF_L - band * 0.5)),
			"CeramicFloor_White", Color(0.94, 0.95, 0.97), false))
	# 沿 Z 的两条（东西）
	for sx: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(band, 0.28, L - band * 2.0),
			Vector3(sx * (HALF_W - band * 0.5), MEZZ, 0.0),
			"CeramicFloor_White", Color(0.94, 0.95, 0.97), false))
	# 玻璃栏板：绕挑空一圈
	var ix: float = HALF_W - band
	var iz: float = HALF_L - band
	for sz: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(ix * 2.0, 0.95, 0.06), Vector3(0.0, MEZZ + 0.62, sz * iz),
			"Glass", Color(0.88, 0.95, 1.0), false, 0.30))
		# 扶手：不锈钢圆管（用细方管近似）
		d.add(K.box(Vector3(ix * 2.0, 0.07, 0.10), Vector3(0.0, MEZZ + 1.12, sz * iz),
			"MetalWall", Color(0.92, 0.94, 0.96)))
	for sx: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(0.06, 0.95, iz * 2.0), Vector3(sx * ix, MEZZ + 0.62, 0.0),
			"Glass", Color(0.88, 0.95, 1.0), false, 0.30))
		d.add(K.box(Vector3(0.10, 0.07, iz * 2.0), Vector3(sx * ix, MEZZ + 1.12, 0.0),
			"MetalWall", Color(0.92, 0.94, 0.96)))
	# 二层墙面上的品牌灯箱：中庭的"商业感"来源。
	# emissive=true —— 灯箱是自发光面，走光照烘焙会比周围墙还暗。
	var bz: float = -12.0
	while bz <= 12.0:
		for sx: float in [-1.0, 1.0]:
			d.add(K.panel(Vector3(sx * (HALF_W - 0.06), MEZZ + 1.4, bz),
				Vector2(2.6, 1.0), "x-" if sx < 0.0 else "x+",
				"RGB_Screen", Color(0.72, 0.86, 1.0), 1.0, false, true))
		bz += 6.0
	# 二层环廊照明：让挑空上沿有光，否则抬头是一片黑
	var lz: float = -14.0
	while lz <= 14.0:
		for sx: float in [-1.0, 1.0]:
			d.lamps.append(K.lamp(Vector3(sx * (HALF_W - 1.8), MEZZ + 1.6, lz),
				Color(0.90, 0.95, 1.0), 1.4, 7.0))
		lz += 7.0

## 两侧店铺门面：玻璃橱窗 + 门头灯箱 + 招牌。做出"商业街"的密度。
static func _shopfronts(d: ChapterData) -> void:
	var z: float = -15.0
	var idx: int = 0
	var signs: Array = ["VendingMachine", "BookShelf_Classroom_White", "Locker",
		"RGB_Screen", "ComputerScreen_BlueScreen", "NormalDoor"]
	while z <= 13.0:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * (HALF_W - 0.08)
			var nx: String = "x-" if sx < 0.0 else "x+"
			# 橱窗玻璃（无碰撞）
			d.add(K.box(Vector3(0.07, 1.9, 3.2), Vector3(x, 1.15, z), "Glass",
				Color(0.90, 0.96, 1.0), false, 0.24))
			# 门头：铝板挑檐 + 灯箱
			d.add(K.box(Vector3(0.55, 0.30, 3.6), Vector3(x - sx * 0.26, 2.42, z),
				"MetalPlateWall", Color(0.78, 0.80, 0.84)))
			d.add(K.panel(Vector3(x - sx * 0.30, 2.05, z), Vector2(3.2, 0.42), nx,
				String(signs[idx % signs.size()]), Color(0.86, 0.94, 1.0), 1.0, false))
			# 橱窗内的陈列（深色块，给玻璃后面内容）。
			# 不用 WoodenBox：平均色 #A06821 是橙木色，一排陈列块读成"橙色垃圾桶"。
			# MetalPlateWall #959E9D 乘 0.55 得到中性深灰展示台。
			d.add(K.box(Vector3(0.5, 1.4, 2.4), Vector3(x - sx * 0.45, 0.70, z),
				"MetalPlateWall", Color(0.55, 0.57, 0.60)))
			# 橱窗灯：让店面在暗部也亮，是商场"夜里也开着"的感觉
			d.lamps.append(K.lamp(Vector3(x - sx * 1.1, 1.9, z),
				Color(0.94, 0.97, 1.0), 1.1, 4.5))
		z += 6.0
		idx += 1

## 天花：双排筒灯 + 中轴长灯带。挑空高 5.2 米，灯要密一点才照得下来。
static func _ceiling(d: ChapterData) -> void:
	# 中轴不放任何吊顶特征。
	# 依据（ch03_00_player 截帧）：30 米连续中轴灯带在 75° FOV 下投影成
	#   "一条纯白竖线把画面从正中劈开"，实测与 ch01 完全同一个现象。
	#   玩家站在中轴上朝 -Z 看，任何沿视线轴延伸的中轴特征都会退化成一条屏幕竖线 ——
	#   这是透视的必然，改宽度/分段都无效（ch01 已实测两次），只能不放。
	#   视线引导改由两条 WarningLine 边线与两侧筒灯完成。
	# 两排筒灯
	var z: float = -16.0
	while z <= 16.0:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * 6.0
			d.add(K.box(Vector3(1.0, 0.09, 1.0), Vector3(x, H - 0.045, z),
				"MetalPlateWall", Color(0.60, 0.62, 0.66)))
			d.add(K.panel(Vector3(x, H - 0.095, z), Vector2(0.86, 0.86), "down",
				"WhiteCeiling_MetalEdge", Color(1.0, 0.99, 0.95), 0.5, true, true))
			d.lamps.append(K.lamp(Vector3(x, H - 0.25, z),
				Color(1.0, 0.98, 0.94), 3.4, 8.5))
		z += 5.5
	# 中轴补光：挑空正中加一排，避免中央地面出现暗带
	var mz: float = -14.0
	while mz <= 14.0:
		d.lamps.append(K.lamp(Vector3(0.0, H - 0.30, mz),
			Color(1.0, 0.98, 0.95), 2.6, 9.0))
		mz += 7.0

## 刷怪点：四角 + 走道两端 + 店铺门前。距出生点 (0,15) 全部 ≥ 6 米。
static func _spawns(d: ChapterData) -> void:
	d.add_spawns([
		Vector3(0.0, 0.0, -16.0), Vector3(-8.0, 0.0, -16.0), Vector3(8.0, 0.0, -16.0),
		Vector3(0.0, 0.0, -11.0), Vector3(-11.0, 0.0, -11.0), Vector3(11.0, 0.0, -11.0),
		Vector3(-11.0, 0.0, -3.0), Vector3(11.0, 0.0, -3.0),
		Vector3(-11.0, 0.0, 5.0), Vector3(11.0, 0.0, 5.0),
		Vector3(-5.0, 0.0, 10.0), Vector3(5.0, 0.0, 10.0),
	])

## 五波。中庭开阔，允许同屏更多人 —— 这是本章的"爽点"。
static func _waves(d: ChapterData) -> void:
	d.wave(14, 12, 1.00, 0.08, 1.04, 1.08, 3.0, 4.0)
	d.wave(18, 16, 0.86, 0.20, 1.10, 1.20, 2.5, 4.0)
	d.wave(22, 20, 0.74, 0.28, 1.16, 1.34, 2.5, 3.5)
	d.wave(26, 24, 0.64, 0.34, 1.22, 1.48, 2.5, 3.5)
	d.wave(34, 28, 0.52, 0.42, 1.30, 1.64, 2.0, 0.0)
