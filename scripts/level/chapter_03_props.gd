## 第三章的道具子模块：二层环廊封边、品牌灯箱、自动扶梯、店铺门面、天花筒灯。
## 挂载节点类型: 无（extends RefCounted，全部 static，由 chapter_03_atrium.build() 调用）
##
## 为什么拆出来：chapter_03_atrium.gd 在补完扶梯后涨到 336 行，
##   超过 PDF 硬红线「单文件 ≤ 300 行」。
##
## 尺寸常量必须在本文件重复声明，不能 preload 父文件 ——
##   父文件 preload 子文件，子文件反向 preload 父文件会形成 Cyclic reference。
##   这是 ch01/ch04 拆分时踩过的同一个坑。
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")

const W := 26.0
const L := 36.0
const H := 5.2
const HALF_W := 13.0
const HALF_L := 18.0
const MEZZ := 2.8

## 二层环廊外沿的深色封边（fascia）。
## 审核员实测（ch03_03_right）楼板底 0.763~0.992 / 玻璃 0.638~0.777 / 扶手 0.579
## / 背后天花 0.588 / 北墙 0.592 —— 全部同档灰白，整层结构压在 34 行（12.6% 屏高）里
## 读不出来。楼板正面也是 CeramicFloor_White 0.94，与天花同色，抬头是一整片白。
## 加 0.30 米高的深色封边后，实测该带 L 从 179 掉到 **54**，挑空沿有了可读硬边。
static func fascia(d: ChapterData) -> void:
	var band: float = 3.4
	var ix: float = HALF_W - band
	var iz: float = HALF_L - band
	for sz: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(ix * 2.0, 0.10, 0.10), Vector3(0.0, MEZZ - 0.14, sz * iz),
			"MetalWall", Color(0.45, 0.47, 0.50), false))
		d.add(K.box(Vector3(ix * 2.0, 0.30, 0.07), Vector3(0.0, MEZZ, sz * iz),
			"MetalWall", Color(0.42, 0.44, 0.48), false))
	for sx: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(0.10, 0.10, iz * 2.0), Vector3(sx * ix, MEZZ - 0.14, 0.0),
			"MetalWall", Color(0.45, 0.47, 0.50), false))
		d.add(K.box(Vector3(0.07, 0.30, iz * 2.0), Vector3(sx * ix, MEZZ, 0.0),
			"MetalWall", Color(0.42, 0.44, 0.48), false))

## 二层墙面上的品牌灯箱 + 环廊照明。
## 法线方向：玩家永远在墙内侧。左墙（sx<0）的内侧朝向 +X，右墙（sx>0）朝 -X。
## 旧写法 "x-" if sx < 0.0 else "x+" 正好反了，20 个灯箱全被背面剔除、
## 一个都不渲染（审核员用 fov75 反算投影坐标实测：三处灯箱位置全是 WhiteWall 灰，
## G-max(R,B) 最大仅 32，若渲染应是 109）。_shell 里墙裙那套写法才是对的。
## 材质必须换：emissive 面 UV 锁 (0.5,0.5)，而 RGB_Screen 中心像素是纯黑，
## 修好法线后会立刻变成一排黑方块。WhiteCeiling_MetalEdge 中心 0.929 是亮白。
static func lightboxes(d: ChapterData) -> void:
	var bz: float = -12.0
	while bz <= 12.0:
		for sx: float in [-1.0, 1.0]:
			d.add(K.panel(Vector3(sx * (HALF_W - 0.06), MEZZ + 1.4, bz),
				Vector2(2.6, 1.0), "x+" if sx < 0.0 else "x-",
				"WhiteCeiling_MetalEdge", Color(0.68, 0.86, 1.0), 1.0, false, true))
		bz += 6.0
	# 环廊照明：让挑空上沿有光，否则抬头是一片黑
	var lz: float = -14.0
	while lz <= 14.0:
		for sx: float in [-1.0, 1.0]:
			d.lamps.append(K.lamp(Vector3(sx * (HALF_W - 1.8), MEZZ + 1.6, lz),
				Color(0.90, 0.95, 1.0), 1.4, 7.0))
		lz += 7.0

## 自动扶梯：中庭的垂直交通。
## 审核员实测 `rg -i "stair|escalat|扶梯|楼梯|ramp"` 在本项目零匹配 ——
## 5.2 米层高 + 2.8 米二层环廊却没有任何上人路径，体量失去说服力：
## 环廊读成"一圈悬空的白板"，而不是"你可以走上去的二层"。
## 全部 body=false（玩家上不去，有碰撞会变成斜插地面的隐形墙 —— 同太阳能板的教训）。
##
## 两版失败的教训（都写在这里，别再试第三次）：
##   ① 沿 Z 跑（z=9.4→14.4，落在南北环廊内沿）：落地端正好在出生点 z=15 旁边，
##      480x270 里只剩一块压在画面下沿的深色矩形，梯身完全在视野外。
##   ② 四组对称（x=±7.4 × z=±9）不接楼板：两端都悬空，读成"天花下挂了两块斜板"。
## 现版：**沿 X 跑**，落地端 x=±4.6、上端 x=±9.6（正好搭在侧向环廊内沿 9.6 上），
##   z=±5 让两组扶梯横跨视野中部 —— 沿视线轴之外的物体才有透视缩短可读。
static func escalators(d: ChapterData) -> void:
	var run: float = 5.0
	var ang: float = rad_to_deg(atan(MEZZ / run))
	var slab_len: float = sqrt(run * run + MEZZ * MEZZ)
	# 14 级踏步：每级沿梯身长 slab_len/14 ≈ 0.41 米，与真实扶梯踏板深度同量级。
	# 扶梯的可读性全靠"一级一级"这个高频纹理，没有踏步就是一块斜板。
	var steps: int = 14
	var step_len: float = slab_len / float(steps)
	var x_bot: float = 4.6
	var x_top: float = 9.6
	var x_mid: float = (x_bot + x_top) * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var zc: float = sz * 5.0
			# 绕 Z 轴正转把 +X 端抬起：sx=+1 朝 +X 上升用 +ang，sx=-1 用 -ang。
			var rot := Vector3(0.0, 0.0, sx * ang)
			# 实心斜板打底：只画 0.07 米踏步 + 0.55 米裙板时，从下往上能直接看穿，
			#   截帧里读成"悬在空中的梯子"。补一块 0.46 米厚的斜板把底面填实，
			#   整组才是一个有体积的斜向构件，而不是几根细梁。
			d.add(K.box(Vector3(slab_len, 0.46, 1.24),
				Vector3(sx * x_mid, MEZZ * 0.5 - 0.20, zc), "MetalPlateWall",
				Color(0.40, 0.42, 0.46), false, 1.0, 0.0, rot))
			for i: int in steps:
				var t: float = (float(i) + 0.5) / float(steps) - 0.5
				var sx_off: float = t * slab_len * cos(deg_to_rad(ang))
				var sy_off: float = t * slab_len * sin(deg_to_rad(ang))
				var tone: float = 0.62 if i % 2 == 0 else 0.45
				d.add(K.box(Vector3(step_len * 0.92, 0.07, 1.12),
					Vector3(sx * (x_mid + sx_off), MEZZ * 0.5 + sy_off, zc),
					"MetalPlateWall", Color(tone, tone + 0.02, tone + 0.05),
					false, 1.0, 0.0, rot))
			# 两侧裙板：比踏步高 0.5 米，是扶梯最好认的轮廓线（亮白 + 深色扶手带）。
			for ez: float in [-0.66, 0.66]:
				d.add(K.box(Vector3(slab_len, 0.55, 0.07),
					Vector3(sx * x_mid, MEZZ * 0.5 + 0.28, zc + ez), "MetalWall",
					Color(0.88, 0.90, 0.93), false, 1.0, 0.0, rot))
				d.add(K.box(Vector3(slab_len, 0.08, 0.11),
					Vector3(sx * x_mid, MEZZ * 0.5 + 0.60, zc + ez), "MetalWall",
					Color(0.22, 0.24, 0.28), false, 1.0, 0.0, rot))
			# 上下两端梳齿板：把梯身"接"到地面与侧向楼板上（第一版缺这个，梯身悬空）。
			d.add(K.box(Vector3(0.9, 0.09, 1.5),
				Vector3(sx * x_bot, 0.045, zc), "MetalPlateWall",
				Color(0.70, 0.72, 0.75), false))
			d.add(K.box(Vector3(0.9, 0.09, 1.5),
				Vector3(sx * x_top, MEZZ + 0.045, zc), "MetalPlateWall",
				Color(0.70, 0.72, 0.75), false))

## 两侧店铺门面：玻璃橱窗 + 门头挑檐 + 招牌 + 陈列台。
static func shopfronts(d: ChapterData) -> void:
	# 南北端墙裙：_shell 的墙裙循环只跑了 x=±13 两面，z=±18 两端完全裸 WhiteWall，
	# 玩家出生点（z=15）回望时是一片没有压脚的白墙，读不出"室内"。
	for sz: float in [-1.0, 1.0]:
		d.add(K.box(Vector3(W, 1.1, 0.08), Vector3(0.0, 0.55, sz * (HALF_L - 0.04)),
			"PoolTiles", Color(0.86, 0.92, 1.0)))
	var z: float = -15.0
	var idx: int = 0
	# 招牌只用「物件贴图」，不用屏幕贴图：
	#   RGB_Screen 中心 texel 是纯黑 (0,0,0)、ComputerScreen_BlueScreen 中心是纯蓝，
	#   而 emissive 面 UV 锁死在 (0.5,0.5)（见 chapter_builder._add_panel），
	#   一旦法线修对，整块招牌就是一片纯黑或纯蓝方块。
	var signs: Array = ["VendingMachine", "BookShelf_Classroom_White", "Locker", "NormalDoor"]
	while z <= 13.0:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * (HALF_W - 0.08)
			# 法线朝室内：左墙（sx<0）内侧朝 +X，右墙（sx>0）内侧朝 -X。
			# 旧写法 "x-" if sx < 0.0 else "x+" 正好反了，招牌全部背面剔除、一个都不渲染。
			var nx: String = "x+" if sx < 0.0 else "x-"
			# 橱窗玻璃（无碰撞）。alpha 传 1.0 —— Glass.png 自身 alpha 中位数 26/255，
			# 再乘 0.24 只剩 2.4%，玻璃等于不存在（详见 _mezzanine 的同款注释）。
			# 高 1.9 → 1.55、中心 y 1.15 → 0.98（范围 0.205~1.755）：
			#   旧玻璃顶到 y=2.10，与招牌底 y=1.84 重叠 0.26 米 ——
			#   招牌有一半埋在玻璃里，玻璃又挡住招牌下半，两者都读不出来。
			d.add(K.box(Vector3(0.07, 1.55, 3.2), Vector3(x, 0.98, z), "Glass",
				Color(0.90, 0.96, 1.0), false, 1.0))
			# 门头：铝板挑檐。body=false —— 旧写法默认 true，在 x=±12.66 处
			# 形成一个向室内伸出 0.34 米的实体碰撞块，玩家会撞到"空气墙"。
			d.add(K.box(Vector3(0.55, 0.30, 3.6), Vector3(x - sx * 0.26, 2.42, z),
				"MetalPlateWall", Color(0.78, 0.80, 0.84), false))
			# 招牌：emissive=true + tiled=false。
			#   emissive：灯箱是自发光面，走光照烘焙会被压到与周围墙同亮（实测招牌带
			#     rgb(189,193,199) 与上方挑檐纯白横带糊成一片）。
			#   tiled=false：招牌是"一块完整画面"，平铺会把物件贴图切成碎片。
			# 高 0.42 → 0.40、宽 3.2 → 2.6（7.6:1 → 6.5:1）：物件贴图被整面拉伸
			#   到 7.6:1 时内容完全不可读，收窄后至少读得出"是一块招牌"。
			#   y 范围 1.85~2.25，与玻璃顶 1.755、门头底 2.27 各留余量，不再穿插。
			d.add(K.panel(Vector3(x - sx * 0.42, 2.05, z), Vector2(2.6, 0.40), nx,
				String(signs[idx % signs.size()]), Color(0.86, 0.94, 1.0), 1.0, false, true))
			# 橱窗内的陈列（深色块，给玻璃后面内容）。
			# 不用 WoodenBox：平均色 #A06821 是橙木色，一排陈列块读成"橙色垃圾桶"。
			# MetalPlateWall #959E9D 乘 0.55 得到中性深灰展示台。
			# body=false —— 玻璃可穿而陈列块挡人，玩家会穿过玻璃撞在货架上。
			d.add(K.box(Vector3(0.5, 1.4, 2.4), Vector3(x - sx * 0.45, 0.70, z),
				"MetalPlateWall", Color(0.55, 0.57, 0.60), false))
			# 橱窗灯：让店面在暗部也亮，是商场"夜里也开着"的感觉
			d.lamps.append(K.lamp(Vector3(x - sx * 1.1, 1.9, z),
				Color(0.94, 0.97, 1.0), 1.1, 4.5))
		z += 6.0
		idx += 1

## 天花：分格梁 + 双排筒灯 + 中轴补光。
static func ceiling(d: ChapterData) -> void:
	# 中轴不放任何吊顶特征。
	# 依据（ch03_00_player 截帧）：30 米连续中轴灯带在 75° FOV 下投影成
	#   "一条纯白竖线把画面从正中劈开"，实测与 ch01 完全同一个现象。
	#   玩家站在中轴上朝 -Z 看，任何沿视线轴延伸的中轴特征都会退化成一条屏幕竖线 ——
	#   这是透视的必然，改宽度/分段都无效（ch01 已实测两次），只能不放。
	# 天花必须分格，否则 26x36 米整片 WhiteCeiling 铺开再被 mipmap 抹平，
	#   读成一团均匀灰雾。审核员实测天花区（x=100..380 y=10..100）lum=0.609 但
	#   sd 只有 0.118 —— 只有全图 sd 0.237 的一半，等于没有任何结构。
	# 必须用 "x"（梁沿 X 延伸、在 Z 上排布）：用 "z" 会在中轴投影成一条竖线。
	d.add(K.ceiling_grid(Vector3(0.0, H - 0.06, 0.0), Vector2(W, L), "x", 3.0, 0.06,
		"MetalPlateWall", Color(0.72, 0.74, 0.78)))
	# 两排筒灯。
	# 步长 5.5 → 4.5：旧序列 -16,-10.5,-5,0.5,6,11.5 在南侧留了 6.5 米无灯空档，
	#   玩家出生点 z=15 正上方一盏灯都没有，开局画面全靠环境光（"出生就暗"）。
	#   新序列 -16,-11.5,-7,-2.5,2,6.5,11,15.5 共 8 排，出生点距最近灯 0.5 米。
	# energy 3.4 → 2.4、range 8.5 → 6.0：旧参数下相邻灯的光池完全重叠饱和，
	#   地面读不出周期光斑（审核员实测中轴 14 行变化 ≤5/255，筒灯排无起伏）。
	var z: float = -16.0
	while z <= 16.0:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * 6.0
			# body=false：筒灯外壳在 5.2 米天花上，玩家永远够不到，
			#   默认 body=true 会平白建 16 个碰撞体。
			d.add(K.box(Vector3(1.0, 0.09, 1.0), Vector3(x, H - 0.045, z),
				"MetalPlateWall", Color(0.60, 0.62, 0.66), false))
			d.add(K.panel(Vector3(x, H - 0.095, z), Vector2(0.86, 0.86), "down",
				"WhiteCeiling_MetalEdge", Color(1.0, 0.99, 0.95), 0.5, true, true))
			d.lamps.append(K.lamp(Vector3(x, H - 0.25, z),
				Color(1.0, 0.98, 0.94), 2.4, 6.0))
		z += 4.5
	# 中轴补光：挑空正中加一排，避免中央地面出现暗带
	var mz: float = -14.0
	while mz <= 14.0:
		d.lamps.append(K.lamp(Vector3(0.0, H - 0.30, mz),
			Color(1.0, 0.98, 0.95), 2.6, 9.0))
		mz += 7.0
