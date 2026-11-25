## 第一章道具层：左墙玻璃幕墙 + 右墙室内街景。
## 挂载节点类型: 无（extends RefCounted，全部 static）
## 为什么单独拆出来（PDF 硬红线：单文件 ≤ 300 行）：
##   chapter_01_lobby.gd 在补齐审核修正后涨到 333 行，超红线。
##   本章的"壳"（地面/天花/柱列/吊顶/前台）决定空间骨架，
##   而"两面侧墙"是密度最高的两块内容（幕墙 30 个分格 + 售货机/储物柜/踢脚线），
##   各自带十几行实测注释。拆开后骨架层 250 行、道具层 100 行。
## 依赖: 只 preload chapter_kit（几何原语），不反向依赖 lobby（避免循环引用）。
extends RefCounted

const K := preload("res://scripts/level/chapter_kit.gd")

## 与 chapter_01_lobby.gd 保持一致的尺寸常量。
## 这里重复声明而不是引用 lobby，是因为 lobby 会 preload 本文件，
## 反向引用会形成 Cyclic reference（Godot 直接报错）。
const W := 22.0
const L := 46.0
const H := 3.6
const HALF_W := 11.0
const HALF_L := 23.0

## 左墙：整面玻璃幕墙 + 幕墙外的落日天空板。
## 天空必须放在玻璃**外面**（更远的 x），否则会被玻璃挡住看不见。
static func left_curtain(d: ChapterData) -> void:
	# 幕墙：墙裙已由 shell 铺好，这里只补玻璃与竖挺
	var z: float = -HALF_L
	var pane: float = 3.0
	while z < HALF_L - 0.01:
		var cz: float = z + pane * 0.5
		# 玻璃：无碰撞，透出后面的天空。
		# alpha 0.22 → 1.0：chapter_builder 的 alpha 是「与贴图 alpha 相乘」，
		#   Glass.png 自身 alpha 中位数只有 26/255（0.102，tmp/TexAlpha 实测
		#   mean=33 p50=26 max=255 opaque=3.1%），再乘 0.22 只剩 2.2% ——
		#   玻璃在数学上等于不存在，截帧里只画出 alpha=255 的高光笔触，
		#   读成"几根竖直细青线"。传 1.0 后最终 0.102 才是真实玻璃透明度。
		# 玻璃高 H-1.05 → H-1.12：旧值底边 y=0.9 与 shell 的蓝裙顶 y=0.9 精确共面，
		#   实测 04_left x=200 竖剖面 y=152..164 恒为 (64,0,0) lum=0.075 ——
		#   7 行纯暗红断层（G=B 全 0），是共面导致的采样撕裂。
		d.add(K.box(Vector3(0.06, H - 1.12, pane - 0.16),
			Vector3(-HALF_W, 0.94 + (H - 1.12) * 0.5, cz), "Glass",
			Color(0.82, 0.92, 1.0), false, 1.0))
		# 竖挺：铝型材，给幕墙分格
		d.add(K.box(Vector3(0.22, H - 0.9, 0.14), Vector3(-HALF_W, 0.9 + (H - 0.9) * 0.5, z),
			"MetalWall", Color(0.88, 0.90, 0.93)))
		# 幕墙的不可见碰撞（审核 P0-2）：玻璃是透明件（body=false），墙裙只到 0.90，
		#   而 player 跳高 1.276 米 > 0.90，玩家能跳出玻璃掉进虚空（全项目无 kill_plane）。
		#   这里补一块与玻璃同尺寸的纯碰撞体：视觉完全不变，但挡住了越界。
		d.add(K.solid(Vector3(0.10, H - 0.9, pane), Vector3(-HALF_W, 0.9 + (H - 0.9) * 0.5, cz)))
		z += pane
	# 顶部横梁
	d.add(K.box(Vector3(0.3, 0.22, L), Vector3(-HALF_W, H - 0.11, 0.0),
		"MetalWall", Color(0.86, 0.88, 0.92)))
	# 幕墙外 3 米处的天空板：朝 +X 面向室内。
	# tiled=false 是必须的 —— 天空是有构图的大图，平铺会变成"一排橙色方块"。
	# 必须用 sky_window.png 而不是 SkyTexture_Sunset：后者是 3860x960 的完整
	# 等距柱状图，下半 50%（y>480）是纯亮黄沙地，整面铺到窗上读成"一面橙色墙"
	# （实测 ch01_00_player.png 左侧就是这样）。sky_window.png 由 tmp/CropSky.gd
	# 裁出地平线以上的 3860x520 天空段，铺上去才是"窗外落日"。
	d.add(K.panel(Vector3(-HALF_W - 3.0, H * 0.5, 0.0), Vector2(L + 8.0, H + 4.0), "x+",
		"sky_window", Color(1.0, 0.96, 0.90), 2.0, false))
	# 天空板补光：模拟落日从左侧灌进来，给白墙一点暖侧光。
	# down_only=false —— 这是整面发光的天空，不是吸顶灯，它要照亮上下两侧。
	var z2: float = -18.0
	while z2 <= 18.0:
		d.lamps.append(K.lamp(Vector3(-HALF_W + 1.2, 2.2, z2),
			Color(1.0, 0.86, 0.68), 0.55, 12.0, false))
		z2 += 9.0

## 右墙：白墙 + 售货机 + 储物柜 + 踢脚线，做出"室内街景"的密度。
static func right_wall(d: ChapterData) -> void:
	var z: float = -16.0
	# 自动售货机（每两台一组，靠墙内凹 0.3 米）。
	# 尺寸 (0.72, 1.95, 1.0) → (1.00, 1.95, 0.72)（审核 P0-5）：
	#   旧值宽 0.72 < 深 1.0，宽深比 0.72 反了 —— 真实售货机是 1.15~1.40 的扁宽箱体，
	#   正面朝向走廊。改成宽 1.00 / 深 0.72 后正立面 1.00×1.95，比例 1:1.95，
	#   才是站在墙边能读出来的机器而不是一根立柱。
	#   x 同步 HALF_W-0.40 → HALF_W-0.37：背面落在 x=10.99，离墙面留 0.01 米防共面。
	while z <= 12.0:
		d.add(K.box(Vector3(1.00, 1.95, 0.72), Vector3(HALF_W - 0.37, 0.975, z),
			"VendingMachine", Color(1.0, 1.0, 1.0)))
		# 机器自身的面板光，让它在暗部也能读出来。
		# 高度 1.5 → 1.62、energy 0.45 → 0.60：贴图 f=0.7~0.9（下三分之一）dark% 达 52.5/61.5
		#   是出货口暗区，本身合法；但光源在 1.5 米时照不到出货口上方，整块读成纯黑。
		#   抬高到 1.62 并加能量，让下段的暗区仍有层次（暗但不是 0/255）。
		d.lamps.append(K.lamp(Vector3(HALF_W - 0.85, 1.62, z),
			Color(0.72, 0.90, 1.0), 0.60, 4.5))
		z += 4.5
	# 储物柜一排（同样离墙 0.04 米，旧值 x∈[10.48,11.00] 贴墙共面）
	var lz: float = 14.0
	while lz <= 20.0:
		d.add(K.box(Vector3(0.52, 2.05, 0.92), Vector3(HALF_W - 0.30, 1.025, lz),
			"Locker_DarkBlue", Color(1.0, 1.0, 1.0)))
		lz += 1.0
	# 踢脚线：收住墙与地的交界，避免"墙插进地板"的塑料感。
	# tint (0.48,0.50,0.54) → (0.95,0.96,0.98)：旧值链路是
	#   0.48 × MetalWall 反照率 0.312 = 0.150，再乘 lit 0.51 与 AO 0.12 = 0.0092
	#   ≈ 2/255 —— 实测 03_right y=218 的 dark<38 占比达 30.0%、y=180..228 整段
	#   20~30%，读成"墙脚一条纯黑横带"。踢脚线该是浅灰金属，不是黑边。
	d.add(K.box(Vector3(0.10, 0.14, L), Vector3(HALF_W - 0.06, 0.07, 0.0),
		"MetalWall", Color(0.95, 0.96, 0.98)))
	d.add(K.box(Vector3(W, 0.14, 0.10), Vector3(0.0, 0.07, -HALF_L + 0.05),
		"MetalWall", Color(0.95, 0.96, 0.98)))
