## 第二章：OFFICE FLOOR —— 现代开放式办公层
## 挂载节点类型: 无（extends RefCounted，静态 build() 返回 ChapterData）
## 视觉目标（用户要求「照片级 + 现代风格 + 不灰暗」）:
##   暖色木地板 + 白色吸音天花 + 玻璃隔断会议室 + 白色办公桌阵列，
##   这是「当代共享办公空间」的通用视觉语言。与第一章的白石大堂拉开色温：
##   第一章是冷白（0.40/0.41/0.43），本章是暖白（0.44/0.44/0.45 + 木地板反光）。
## 布局（24 宽 x 40 长 x 3.2 高）:
##   - 中轴 2.4 米宽白色石材走道，两侧木地板办公区
##   - 右侧 x=5.6 起是两间玻璃隔断会议室（z=-11..-6 与 z=-1..4）
##   - 左侧 x=-8.6 / -4.2 两列工位，每列 8 张桌子
##   - 远端 z=-20 是黄色品牌墙（本章唯一的强色块，避免整体发闷）
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")

## 办公层尺寸常量。改这里就能整体缩放，不用逐条改坐标。
const W := 24.0        # X 向宽度
const L := 40.0        # Z 向长度
const H := 3.2         # 净高（比大堂低，办公层压顶更贴近真实）
const HALF_W := 12.0
const HALF_L := 20.0

static func build() -> ChapterData:
	var d := ChapterData.make("chapter_02", "OFFICE FLOOR", "NEO-TOKYO · OPEN PLAN 14F")
	d.objective = "CLEAR THE OFFICE"
	d.mesh_step = 1.0
	# 暖白环境光。比第一章略提一档，因为木地板会吃掉一部分亮度。
	# ground 用偏暖的 0.24/0.215/0.19，模拟木地板向上反射的暖色。
	# ambient sky 0.44 → 0.36、ground 抬到 0.30/0.27/0.23（审核 P0-1）：
	# 0.44 的均匀环境光把全场压在同一亮度带，六机位 sd 全部 0.160~0.198 < 0.20，
	# 00_player 亮灰白占 51.0%、中性灰+亮灰白合计 66.4%。降 sky 拉开明暗、
	# 抬 ground 保住木地板向上的暖色反射，两者一起把直方图摊开。
	d.with_ambient(Color(0.36, 0.36, 0.37), Color(0.30, 0.27, 0.23))
	# 后期：contrast 1.08 → 1.22、lift 0.040 → 0.010。
	# 原参数下天花区（占屏 35.2%）实测 lum 219.7，比全图 179.8 高 40 灰阶，
	# 04_left 出现 23/220 个 24x24 纯平涂块 —— 提对比、收 lift 是把中调摊开的正解。
	# brightness 1.06 保留：走道烘焙 0.826 代入 (0.826-0.5)*1.22+0.5+0.010 = 0.908，
	# 再 ×1.06 = 0.963，仍在 1.0 以下，不会被 24 阶量化成纯白条。
	d.with_post({
		"brightness": 1.06, "contrast": 1.22, "saturation": 1.10,
		"lift": 0.031, "vignette_strength": 0.16, "scanline_strength": 0.05,
		"palette_levels": 12.0, "dither_strength": 0.18,
		"curvature": 0.0, "chromatic_aberration": 0.35,
	})
	d.with_player(Vector3(0.0, 0.0, 15.0), 0.0)

	_shell(d)
	_glass_rooms(d)
	_desks(d)
	_ceiling(d)
	_spawns(d)
	_waves(d)
	return d

## 地面 / 天花 / 四面墙。panel 法线朝内，站在房间里才看得见。
static func _shell(d: ChapterData) -> void:
	# 地面：木地板
	d.add(K.panel(Vector3(0.0, 0.0, 0.0), Vector2(W, L), "up", "WoodenFloor",
		Color(1.0, 1.0, 1.0)))
	# 木地板拼装缝：2.4 米一格的实木复合板分格。WoodenFloor 贴图自带的板缝
	# 是 200px 内 4~5 条（世界 1 米级），铺满 24x40 米后被 mipmap 抹成一层
	# 均匀棕雾，地面没有任何尺度参照（与 ch01「一整块白塑料」同源）。
	# tint 0.62 比砖面深一档，读成拼板之间的暗缝；材质用同一种木料，
	# 不换深色材质 —— 木地板缝是"两块板靠在一起"，不是"画了条黑线"。
	d.add(K.floor_seams(Vector3(0.0, 0.0, 0.0), Vector2(W, L), 2.4,
		"WoodenFloor", Color(0.62, 0.60, 0.58), 0.03))
	# 中轴走道：白色石材。抬 12mm 避免与木地板 z-fighting。
	# tint 从 0.98 降到 0.88：走道是全章最亮的平面（灯正上方），
	# 烘焙 0.826 已接近 0.85 的可读上限，再乘接近 1.0 的 tint 就顶到削顶。
	d.add(K.panel(Vector3(0.0, 0.012, 0.0), Vector2(2.4, L), "up", "CeramicFloor_White",
		Color(0.88, 0.88, 0.90), 0.5))
	# 天花：白色吸音板。
	# 关键实测：顶点色在 1.0 处硬截断，初版 tint 0.95 → 1.24 完全无效
	#   （1.24 被截到 1.0，实际渲染值与原值一致）。天花 lit 0.61 已经够亮，
	#   乘 WhiteCeiling 的 #EDEDED(0.929) 得 0.567 —— 吸音板正常明度，保持 0.95 即可。
	# tint 0.95 → 0.86（审核 P0-1）：天花区占屏 35.2%、实测 lum 219.7 比全图 179.8
	# 高 40 灰阶，是「画面读成一片浅灰云雾」的主因。压到 0.86 后天花落到 190 附近，
	# 与地面 0.74 的烘焙亮度形成正常层间关系。
	d.add(K.panel(Vector3(0.0, H, 0.0), Vector2(W, L), "down", "WhiteCeiling",
		Color(0.86, 0.86, 0.87)))
	# 吊顶分缝格栅：与第一章同一个结论 —— WhiteCeiling 平均色 #EDEDED 近乎纯白、
	# 细节极少，24x40 米整片铺开再被 mipmap 抹平后读成"一团均匀浅灰云雾"，
	# 分不出这是装出来的吸音板吊顶。tmp/Crop 实测 ch02_00_player 天花三处
	# rgb(192,189,186) / rgb(199,199,199) / rgb(192,189,187) —— 差 7/255，
	# 人眼读不出任何结构。铺 3x4 米两向格栅后才有板的边界。
	# 只沿 "x" 排（梁沿 X 延伸、在 Z 方向间隔）：沿 "z" 的那一向会有一条
	# 正好压在 x=0 中轴上，从出生点朝 -Z 看会投影成贯穿画面的竖线（第一章已踩过）。
	d.add(K.ceiling_grid(Vector3(0.0, H - 0.03, 0.0), Vector2(W, L), "x", 4.0,
		0.05, "WhiteCeiling", Color(0.86, 0.86, 0.87)))
	# 远端品牌墙：整面暖黄。整章唯一的强色块，没有它画面会是一片米白。
	# tint 加暖：环境光 0.44 偏中性，会把 YellowWall 的 R-B 差（贴图 89）洗成 14，
	# 黄墙读成中性灰、本章失去色彩锚点。乘 (1.0,0.94,0.80) 预补偿去饱和。
	d.add(K.panel(Vector3(0.0, H * 0.5, -HALF_L), Vector2(W, H), "z+", "YellowWall",
		Color(1.0, 0.94, 0.80)))
	d.add(K.panel(Vector3(0.0, H * 0.5, HALF_L), Vector2(W, H), "z-", "WhiteWall",
		Color(0.94, 0.94, 0.95)))
	d.add(K.panel(Vector3(-HALF_W, H * 0.5, 0.0), Vector2(L, H), "x+", "WhiteWall",
		Color(0.97, 0.97, 0.98)))
	d.add(K.panel(Vector3(HALF_W, H * 0.5, 0.0), Vector2(L, H), "x-", "WhiteWall",
		Color(0.96, 0.96, 0.97)))
	# 踢脚线：深色收边，避免"墙插进地板"的塑料感
	d.add(K.box(Vector3(0.10, 0.12, L), Vector3(-HALF_W + 0.05, 0.06, 0.0),
		"MetalWall", Color(0.52, 0.54, 0.58)))
	d.add(K.box(Vector3(0.10, 0.12, L), Vector3(HALF_W - 0.05, 0.06, 0.0),
		"MetalWall", Color(0.52, 0.54, 0.58)))
	d.add(K.box(Vector3(W, 0.12, 0.10), Vector3(0.0, 0.06, -HALF_L + 0.05),
		"MetalWall", Color(0.52, 0.54, 0.58)))
	# 近端踢脚线：02_back 机位朝 +Z 回望时，近端墙脚原本是光板
	d.add(K.box(Vector3(W, 0.12, 0.10), Vector3(0.0, 0.06, HALF_L - 0.05),
		"MetalWall", Color(0.52, 0.54, 0.58)))

## 两间玻璃隔断会议室。玻璃用 alpha 0.72 无碰撞 —— 有碰撞就变成看不见的墙。
static func _glass_rooms(d: ChapterData) -> void:
	var rooms: Array = [[-11.0, -6.0], [-1.0, 4.0]]
	for r: Array in rooms:
		var z0: float = r[0]
		var z1: float = r[1]
		var cz: float = (z0 + z1) * 0.5
		var depth: float = z1 - z0
		# 室内地面：浅灰地毯块，把会议室从木地板里区分出来。
		# 不用 survival__Backroom__CarpetFloor —— 那张图平均色 #C9C178 是黄绿色，
		# 无论怎么 tint 都会把会议室读成"草地"（实测放大后确实是黄绿色块）。
		# WhiteWall_Dirty #C0C0C0 乘 0.80 得到中性浅灰，才是办公地毯。
		d.add(K.box(Vector3(5.6, 0.02, depth), Vector3(8.7, 0.011, cz),
			"WhiteWall_Dirty", Color(0.80, 0.80, 0.82), false))
		# 朝走廊的长边玻璃（沿 Z 延伸，法线 ±X）。材质换 Glass_Pane、alpha 0.72。
		# 关键实测（审核 P0-3）：chapter_builder 的 alpha 是「与贴图 alpha 相乘」，
		#   Glass.png 的 alpha p50 只有 26/255(0.102)，所以原 alpha 0.42 的有效值
		#   = 0.42 × 0.102 = 0.043，与背后白墙 rgb(196,197,196) 混合后理论 B-R 只有 3
		#   （实测 0~11，玻璃正立面青像素仅 25.0%）。章节参数封顶 1.0，有效 alpha
		#   数学上不可能超过 0.102 —— 必须换贴图。Glass_Pane.png 的 alpha 均值已提到
		#   108.6/255(0.426)，配 0.72 得有效 0.307，B-R ≈ 0.31×59 ≈ 18，玻璃膜成立。
		# 长玻璃在 cz 处留 0.7 米门洞：原四面围合，长玻璃 x=5.6 与短玻璃 x=5.9 之间
		#   只有 0.3 米缺口，玩家胶囊半径 0.4 米挤不进去，6 个刷怪点全部困在室内。
		# 玻璃高 2.55 → 3.18：原顶面 2.55 与天花 3.2 之间留 0.65 米空框，
		#   审核实测该区 lum 仅 32~53，是画面里最突兀的一条黑带。
		var gh: float = 3.18
		var gy: float = gh * 0.5
		d.add(K.box(Vector3(0.07, gh, cz - 0.35 - z0), Vector3(5.6, gy, (z0 + cz - 0.35) * 0.5),
			"Glass_Pane", Color(0.80, 0.90, 1.0), false, 0.72))
		d.add(K.box(Vector3(0.07, gh, z1 - cz - 0.35), Vector3(5.6, gy, (cz + 0.35 + z1) * 0.5),
			"Glass_Pane", Color(0.80, 0.90, 1.0), false, 0.72))
		# 两端的短边玻璃
		for zz: float in [z0, z1]:
			d.add(K.box(Vector3(5.6, gh, 0.07), Vector3(8.7, gy, zz), "Glass_Pane",
				Color(0.80, 0.90, 1.0), false, 0.72))
		# 铝型材框：顶梁 + 竖挺，给出幕墙分格感
		d.add(K.box(Vector3(0.12, 0.10, depth), Vector3(5.6, gh + 0.03, cz),
			"MetalWall", Color(0.86, 0.88, 0.91)))
		d.add(K.box(Vector3(5.6, 0.10, 0.12), Vector3(8.7, gh + 0.03, z0),
			"MetalWall", Color(0.86, 0.88, 0.91)))
		d.add(K.box(Vector3(5.6, 0.10, 0.12), Vector3(8.7, gh + 0.03, z1),
			"MetalWall", Color(0.86, 0.88, 0.91)))
		var mz: float = z0 + 2.0
		while mz < z1:
			# 门洞处不放竖挺，否则门洞又被封死
			if absf(mz - cz) < 0.45:
				mz += 2.5
				continue
			# 竖挺 x 从 5.6 挪到 5.53（贴玻璃内侧）：两者共面时 AABB 重叠体积
			# 实测 0.0161 m³（全表最大），Z 序不稳会出现闪烁的斜切边。
			# tint 0.62 → 0.30（审核 P0-3）：实测渲染 146~190，理论 81×0.62=50，
			#   说明环境光把铝框抬到与玻璃同亮，分格线完全看不见。
			d.add(K.box(Vector3(0.13, gh, 0.09), Vector3(5.53, gy, mz),
				"MetalWall", Color(0.30, 0.32, 0.36)))
			mz += 2.5
		# 会议桌 + 腿板（给玻璃后面一点内容，否则会议室是空盒子）
		# 桌面 WoodenBox → MetalPlateWall（审核 P0-5）：WoodenBox 平均色 (160,104,33)
		#   乘 tint(0.82,0.78,0.72) 理论 rgb(131,81,24)，实测 (90,50,0)/(121,71,0)/(97,49,10)
		#   —— B 通道只有 0~19，读成"烧焦的木板"。换中性铝灰才能与木地板区分开。
		# 腿板长 1.3 → 3.2：桌长 3.4 米只撑中央 1.3 米，两端各悬空 1.05 米。
		d.add(K.box(Vector3(1.5, 0.06, 3.4), Vector3(8.6, 0.74, cz),
			"MetalPlateWall", Color(0.72, 0.70, 0.66)))
		d.add(K.box(Vector3(1.3, 0.72, 3.2), Vector3(8.6, 0.36, cz),
			"MetalPlateWall", Color(0.92, 0.92, 0.94)))
		# 会议室灯：每间两盏、range 7.0。
		# 原来单盏 range 5.0 覆盖不了 5.6x5.0 的房间：角落距灯 4.8 米，
		# t=1-4.8/5=0.04、atten≈0.0016 几乎为零，室内完全没有梯度。
		d.lamps.append(K.lamp(Vector3(8.6, H - 0.15, cz - 1.6),
			Color(0.96, 0.97, 1.0), 1.8, 7.0))
		d.lamps.append(K.lamp(Vector3(8.6, H - 0.15, cz + 1.6),
			Color(0.96, 0.97, 1.0), 1.8, 7.0))

## 工位阵列。每张桌子 = 桌面 + 挡板 + 显示器，读得出是工位而不是一排白盒子。
## 引入确定性扰动：9 排 x 2 列完全等距等尺寸时，俯视读成复制粘贴的方格阵
## （审核实测 05_top 一眼 18 个一模一样方块）。用排号取模做「非随机但不等距」，
## 保证每次构建结果一致（构建期烘焙不能有随机，否则光照不可复现）。
static func _desks(d: ChapterData) -> void:
	var z: float = -16.0
	var row: int = 0
	while z <= 12.0:
		for x: float in [-8.6, -4.2]:
			# 桌面
			d.add(K.box(Vector3(1.7, 0.06, 0.90), Vector3(x, 0.745, z),
				"MetalBox_White", Color(0.96, 0.96, 0.97)))
			# 桌腿（两侧挡板，比四根细腿更省面且更像办公家具）
			# 不用 MetalWall：平均色 #4F4F4F 乘 0.70 后实测渲染 rgb(45,45,45)，
			# 一排桌子读成"悬空的黑色积木"。MetalPlateWall #959E9D 乘 0.92 才是浅灰桌腿。
			# 高 0.70 → 0.72（审核 P1）：原顶面 0.71 与桌面底 0.715 差 5mm，
			#   投影成 lum=63.3 的黑缝；加高后顶面 0.72 与桌面实心相交。
			d.add(K.box(Vector3(1.62, 0.72, 0.06), Vector3(x, 0.36, z - 0.40),
				"MetalPlateWall", Color(0.92, 0.93, 0.95)))
			d.add(K.box(Vector3(1.62, 0.72, 0.06), Vector3(x, 0.36, z + 0.40),
				"MetalPlateWall", Color(0.92, 0.93, 0.95)))
			# 显示器（深色面板，是画面里唯一的"屏幕黑"）
			# tint 从 0.72/0.80/0.90 降到 0.52/0.62/0.74：ComputerScreen_BlueScreen
			# 贴图本身是纯 (0,0,255)，高 tint 下成为全画唯一的 100% 饱和纯蓝块
			# （实测 04_left 蓝像素 930 个 mean rgb(2,3,91)），与整体 0.05~0.22 的
			# 饱和度均值严重脱节。压暗后读成"暗着的显示器"而不是蓝色色块。
			# y 1.02 → 0.965（审核 P1）：原底面 0.83 与桌面顶 0.775 之间悬空 55mm。
			d.add(K.box(Vector3(0.62, 0.38, 0.05), Vector3(x, 0.965, z - 0.18),
				"ComputerScreen_BlueScreen", Color(0.52, 0.62, 0.74)))
			# 工位隔板：吸音毛毡。不用 survival__Backroom__CarpetFloor（黄绿），
			# 改 WhiteWall_Dirty #C0C0C0 乘 0.96 —— 中性浅灰，与白桌面拉开一档。
			# 高度固定 0.49（审核 P2）：原按排轮换 0.52/0.46/0.58 使三种底面落在
			#   0.76/0.79/0.73，全都不在桌面顶 0.775 上，俯视是一片错位悬空板。
			#   固定 0.49 时底面恰为 0.775，与桌面严丝合缝。
			d.add(K.box(Vector3(1.70, 0.49, 0.04), Vector3(x, 1.02, z + 0.44),
				"WhiteWall_Dirty", Color(0.96, 0.96, 0.98)))
			# 椅子 + 椅背 + 笔记本 + 绿植（审核 P0-4）：
			# 全章 chair|seat|plant|printer 零匹配，04_left 下半 y=200..240 lum 仅 107.3、
			# 纯蓝像素 1.57%、sat 0.112 六图最低 —— 工位阵列读成一排白盒子。
			# 加人坐的那一侧才有"这是工位"的语义，也把桌面下方的空腔填出层次。
			d.add(K.box(Vector3(0.46, 0.06, 0.46), Vector3(x, 0.46, z - 0.78),
				"MetalPlateWall", Color(0.42, 0.44, 0.48)))
			d.add(K.box(Vector3(0.46, 0.52, 0.06), Vector3(x, 0.72, z - 0.99),
				"MetalPlateWall", Color(0.38, 0.40, 0.44)))
			d.add(K.box(Vector3(0.06, 0.40, 0.06), Vector3(x, 0.23, z - 0.78),
				"MetalWall", Color(0.30, 0.32, 0.35)))
			# 笔记本：合盖状态的深灰板，压在桌面顶 0.775 上
			d.add(K.box(Vector3(0.34, 0.02, 0.24), Vector3(x + 0.42, 0.786, z + 0.02),
				"MetalPlateWall", Color(0.34, 0.36, 0.40)))
			# 绿植：盆 + 冠。本章唯一的高饱和绿，给 04_left 补色相
			d.add(K.box(Vector3(0.26, 0.22, 0.26), Vector3(x - 0.62, 0.885, z + 0.10),
				"MetalPlateWall", Color(0.72, 0.70, 0.66)))
			d.add(K.box(Vector3(0.34, 0.30, 0.34), Vector3(x - 0.62, 1.14, z + 0.10),
				"survival__Backroom__CarpetFloor", Color(0.34, 0.52, 0.30)))
		z += 3.6 + (0.35 if row % 3 == 1 else 0.0)
		row += 1

## 吊顶灯带。每盏灯登记一个构建期光源，运行时不产生节点。
static func _ceiling(d: ChapterData) -> void:
	var z: float = -18.0
	while z <= 18.0:
		for x: float in [-7.0, 0.0, 7.0]:
			# 灯槽（深铝框）。body=false：灯槽不该当 AO 遮挡物。
			# 灯槽顶面 y=3.16 紧贴天花 y=3.2（间隙 0），登记进 AO 网格后
			# 会把正上方的天花采样点全部压暗，天花出现周期性灰斑
			# （实测 y=8 横剖面 min 0.422 / p50 0.527 / max 0.617，呈 150→107→149 起伏）。
			d.add(K.box(Vector3(2.2, 0.08, 0.40), Vector3(x, H - 0.04, z),
				"MetalPlateWall", Color(0.60, 0.62, 0.66), false))
			# 发光面（emissive：跳过光照烘焙，否则会比周围天花还暗）
			d.add(K.panel(Vector3(x, H - 0.085, z), Vector2(2.0, 0.30), "down",
				"WhiteCeiling_MetalEdge", Color(1.0, 0.99, 0.95), 0.5, true, true))
			# 三列灯 x=-7/0/7，与两列工位（-8.6/-4.2）错开，光才落在桌面上而不是隔板上
			# energy 3.0 → 4.2：本章层高只有 3.2 米、灯距地面 3.0 米，
			# 烘焙实测天花 0.61、工位桌面 0.75，整体比第一章低一档。
			d.lamps.append(K.lamp(Vector3(x, H - 0.20, z),
				Color(1.0, 0.97, 0.92), 4.2, 6.5))
		z += 6.0

## 刷怪点：四角 + 走道两端。距出生点 (0,15) 全部 ≥ 6 米。
static func _spawns(d: ChapterData) -> void:
	d.add_spawns([
		Vector3(0.0, 0.0, -18.0), Vector3(-7.0, 0.0, -18.0), Vector3(7.0, 0.0, -18.0),
		Vector3(0.0, 0.0, -13.0), Vector3(-10.5, 0.0, -13.0), Vector3(10.5, 0.0, -13.0),
		Vector3(-10.5, 0.0, -5.0), Vector3(10.5, 0.0, -5.0),
		Vector3(-10.5, 0.0, 3.0), Vector3(10.5, 0.0, 3.0),
		Vector3(-6.0, 0.0, 9.0), Vector3(6.0, 0.0, 9.0),
	])

## 五波。比第一章更密 —— 办公层空间窄，被堵在工位间就是死。
static func _waves(d: ChapterData) -> void:
	d.wave(12, 9, 1.05, 0.04, 1.02, 1.05, 3.0, 4.0)
	d.wave(16, 13, 0.90, 0.16, 1.08, 1.16, 2.5, 4.0)
	d.wave(20, 17, 0.78, 0.24, 1.14, 1.28, 2.5, 3.5)
	d.wave(24, 21, 0.66, 0.32, 1.20, 1.42, 2.5, 3.5)
	d.wave(30, 25, 0.55, 0.40, 1.26, 1.58, 2.0, 0.0)
