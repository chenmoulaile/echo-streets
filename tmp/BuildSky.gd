## 把 SkyTexture_Sunset（3860x960，非 2:1，不是合法等距柱状图）转成标准 2:1 equirect。
## 为什么必须转：PanoramaSkyMaterial 按等距柱状投影采样，v=0.5 必须是地平线。
##   原图地平线在 50% 处，直接喂给 sky 会让"地面"部分铺满下半屏（已实测）。
##
## 俯瞰城市（48F 天台）的正确画面构成，两半分开画：
##   上半 v<0.5：落日天空 + 远景摩天楼剪影，楼体从地平线**向上**刺入天空。
##   下半 v>0.5：从高空俯视的城市地面 —— 街区屋顶、街道网格、越远越雾。
## 初版两处几何写反（都被自检抓出）：
##   ① 楼体画在地平线**下方**（读成一排黑柱挂在天空下面）；
##   ② 下半只有垂直渐变，零水平结构（截帧读成"沙漠公路"）。
##
## 用法: Godot_v4.7.2-stable_win64_console.exe --path D:\mygame --headless res://tmp/sky_build_runner.tscn
extends Node

const SRC := "res://assets/materials/SkyTexture_Sunset.png"
const OUT := "res://assets/textures/sky_rooftop_equirect.png"
const OUT_W := 2048
const OUT_H := 1024

## 地平线雾化带高度（输出像素）。0 会让天空与地面一刀切：
## 实测贴图本体 y=510 (247,152,8) → y=512 (177,91,12) 是 43 级硬切。
## 56 → 96（ch04 审核实测）：整行均值 y=498 L=0.213（谷底，楼体底边）→
##   y=512 L=0.466（地面起始行），14 行内亮度反弹 0.253、R 通道 +96。
##   56px 带在 512 行处的权重只剩 (t*t)=0.25，压不住 146 行铺出来的城市底色。
const HAZE_PX := 96
## 远景楼群层数。三层（远/中/近）才有纵深，单层读成"一排骨牌"。
const LAYERS := 3

func _ready() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if src == null:
		print("[sky_build] 源图加载失败 %s" % SRC)
		get_tree().quit(1)
		return
	if src.is_compressed():
		src.decompress()
	print("[sky_build] src %dx%d" % [src.get_width(), src.get_height()])

	var horizon: int = _find_horizon(src)
	print("[sky_build] horizon row = %d / %d (%.1f%%)" % [
		horizon, src.get_height(), 100.0 * float(horizon) / float(src.get_height())])

	var out := Image.create(OUT_W, OUT_H, false, Image.FORMAT_RGB8)
	var half: int = OUT_H / 2

	# --- 上半：天空段（源 0..horizon）等比拉伸到 v∈[0, half) ---
	var sky_band: Image = src.get_region(Rect2i(0, 0, src.get_width(), horizon))
	sky_band.resize(OUT_W, half, Image.INTERPOLATE_BILINEAR)
	# blit_rect 不做格式转换：源 RGBA8 直接拷进 RGB8 目标会静默失败（结果是全黑）。
	# 必须先 convert 成同格式再 blit。
	sky_band.convert(Image.FORMAT_RGB8)
	out.blit_rect(sky_band, Rect2i(0, 0, OUT_W, half), Vector2i(0, 0))
	var check := out.get_pixel(OUT_W / 2, 4)
	if check.r + check.g + check.b < 0.02:
		print("[sky_build] ERROR blit 失败：顶部像素 %s 为黑" % check.to_html(false))

	# 地平线实测色，作为雾化与远楼的基准色。
	#
	# 降饱和（第三轮修正，目视成品确认）：直接取地平线行均值得到 c56b0f ——
	#   sat=0.85 的高饱和橙。用它当雾化终点，整条地平线被涂成一条纯橙实心带，
	#   与上下都接不上，比原来的硬切更假。
	#   真实大气雾在逆光下是「被阳光染暖的灰白」，不是橙。
	#   这里把色相留住、把饱和度砍到 0.42 左右（向等亮度灰靠 58%）。
	var hz := _row_mean(src, horizon - 1)
	var hz_l: float = hz.r * 0.299 + hz.g * 0.587 + hz.b * 0.114
	var hz_gray := Color(hz_l, hz_l, hz_l)
	var haze_raw: Color = Color(hz.r * 0.80, hz.g * 0.72, hz.b * 0.68)
	var haze: Color = hz_gray.lerp(haze_raw, 0.42)
	var far := Color(0.075, 0.072, 0.082)

	# --- 落日盘：显式绘制，不依赖源图 ---
	# 依据（ch04 审核 P2-4 实测）：源图的太阳盘半径只有 25~30px，
	#   左侧亮 0.848 而右侧只有 0.576 —— 不对称，像被云切掉一半；
	#   光晕中心还在太阳上方 45°（y=208 lum=0.684 > 太阳正下方 y=256 的 0.507）。
	# 太阳必须画在楼群**之前**，这样近层楼能自然遮住它下半部分。
	_paint_sun(out, half)

	# --- 上半：远景摩天楼，从地平线向上长 ---
	_paint_skyline(out, half, haze, far)

	# --- 下半：高空俯视的城市地面 ---
	_paint_city_ground(out, half, haze, far)

	# --- 地平线雾化：**不再单独做一遍** ---
	# 第四轮结论（目视成品确认）：城市地面底色本身就是从 haze 起渐变
	# （见 _paint_city_ground 的 smoothstep(0,0.45,t)），楼群底边正好落在 half 行、
	# 与地面首行同色 —— 接缝在数学上已经连续。
	# 再叠一遍 _paint_haze 等于「用 haze 去雾化已经从 haze 出发的地面」，
	# 结果就是地平线上横贯全宽的一条纯 haze 亮带（前几版反复出现的那条）。
	# 保留 _paint_haze 函数但不再调用：以后若改回"地面不从 haze 起步"才需要它。

	# --- 首尾接缝混合：等距柱状贴图 u=0 与 u=1 是同一条经线 ---
	# 依据（ch04 审核 P1-2 实测）：上半整列均值 x=0 rgb(138,73,59) L=0.336 /
	#   x=2047 rgb(146,78,61) L=0.358（R 差 8、G 差 7、B 差 3、L 差 0.022），
	#   且 x=0..2 与 x=2045..2047 各自内部恒定（纯色块边界非渐变）。
	#   panorama_sky_rot.gdshader 的 u = atan(r.z,r.x)*0.15915494+0.5 在 ±π 处 wrap，
	#   首尾不等即在天上露一条竖缝。
	_blend_seam(out, 8)

	var err: int = out.save_png(ProjectSettings.globalize_path(OUT))
	print("[sky_build] saved %s %dx%d err=%d" % [OUT, out.get_width(), out.get_height(), err])
	print("[sky_build] haze=%s far=%s" % [haze.to_html(false), far.to_html(false)])
	# 自检 1：天空段必须有「沿 x 的结构」（楼群），不能是纯天空渐变。
	# 判据必须是行内方差：楼群是水平错落的，同一行里不同 x 落在不同楼/楼间空隙上，
	#   但整行均值几乎不变 —— 用「相邻行均值差」永远读成 0（初版就是这个错）。
	# 采样行必须落在楼群带内（half-64..half-4）。实测：
	#   y=452（half-60）hvar=0.00377；y=532（half+20）hvar=0.00006 —— 后者已在雾化带里，
	#   HAZE_PX=56 会把 512..568 整段抹平，在那里量必然读 0。
	print("[sky_build] skyline_hvar=%.4f (需 >0.002)" % _row_horizontal_var(out, half - 60))
	# 自检 2：地平线以上必须有楼体（暗于天空），否则只是纯天空。
	print("[sky_build] above_dark_ratio=%.3f (需 >0.05)" % _dark_ratio(out, half - 40, 0.62))
	get_tree().quit()

## 远景摩天楼：楼体在地平线**上方**，底边贴地平线，向上长。
##
## 尺度换算（初版错在这里，被 ch04 截帧抓出）：
##   等距柱状投影里上半 512px 对应整个 90°（天顶→地平线），
##   所以 1px ≈ 0.176°。初版楼高上限 170px = 30° 仰角，
##   相当于一栋楼贴着天台边竖起来 —— 截帧里就是"几面巨型黑墙把落日挡死"。
##   真实尺度：2 公里外的 200m 高楼仰角约 5.7° = 32px。
##
## 第二轮修正（ch04 审核报告 P0-3 / P2-1，全部实测数据）：
##   ① 楼体饱和度 sat=0.769 比天空 sat=0.758 还高 —— 真实远景楼在空气透视下
##      必须降饱和、向天空色靠拢，否则读成"剪纸剪影贴在天上"。
##      修法：lerp 到 far 之后再强制 `tone.lerp(haze, 0.35)` 拉回雾色。
##   ② 亮度直方图只有两个峰（楼体 0.15~0.25 占 40.8%、天空 0.50~0.65 占 53.6%），
##      中间调 0.25~0.50 仅 4.6% —— 只有两层，没有第三层中景。
##      修法：层间 tone 必须错开，且中层要落在中间调区间里。
##   ③ 楼高 h_avg=24.7px（仰角 6.86°）低于「2km 外 200m 楼 32px」，
##      全城无一座超高层。修法：h_max 14+50*depth → 18+95*depth（近层 ~113px≈20°）。
##   ④ 单色 fill_rect 无立面，1000+ 像素绝对纯色。修法：每栋楼加竖向窗带。
func _paint_skyline(out: Image, half: int, haze: Color, far: Color) -> void:
	var rng := RandomNumberGenerator.new()
	# 固定种子：构建期烘焙不能有随机，否则画面不可复现。
	rng.seed = 20261124
	for layer: int in range(LAYERS):
		var depth: float = float(layer) / float(maxi(LAYERS - 1, 1))
		var h_min: int = 4 + int(depth * 14.0)
		var h_max: int = 18 + int(depth * 95.0)
		# 楼体必须比天空暗才有剪影感，但不能"纯色"。
		# 近层压到 0.72 —— 逆光楼体是暗剪影，靠楼顶亮边与雾化保留体积感。
		var tone: Color = haze.lerp(far, 0.42 + 0.30 * depth)
		# 强制降饱和（审核实测的核心修法）：把楼体往雾色方向拉回 35%，
		# 让它落在「天空色 与 深灰」之间，才是大气透视里的远景楼。
		#
		# 但必须**往等亮度灰拉**、不能往 haze 拉（第五轮修正，目视成品确认）：
		#   haze 是亮米色 b28c65（L≈0.58），lerp 到它会把楼体整体提亮 ——
		#   上一版截帧里楼群是"灰白色高塔立在橙色天空里"，比天空还亮，
		#   完全失去逆光剪影感。真实远景楼的亮度由雾厚度决定，降饱和只改色度。
		#   正解：取自身亮度做灰，再与原色混合 —— 只改色度、不动亮度。
		var tone_l: float = tone.r * 0.299 + tone.g * 0.587 + tone.b * 0.114
		tone = tone.lerp(Color(tone_l, tone_l, tone_l), 0.45)
		# 楼宽：近层楼更宽（34+26 → 44+40）。审核实测初版平均每座 108px≈19° 视野，
		# 19 座铺满 2048px，读成"一排等宽盒子"。
		var x: int = 0
		while x < OUT_W:
			var w: int = rng.randi_range(14 + layer * 10, 44 + layer * 40)
			var h: int = rng.randi_range(h_min, h_max)
			var draw_w: int = mini(w, OUT_W - x)
			if draw_w <= 0:
				break
			var top_y: int = maxi(half - h, 0)
			# 楼体：从 top_y 到地平线，**底部渐隐进雾**。
			#
			# 逐行渐变而非单色 fill_rect（第四轮修正，目视成品确认）：
			#   单色楼体直到底行 half 才结束，而地面首行是 haze（亮米色）——
			#   两者在地平线上硬碰，读成"一排黑盒子立在一层亮米色板上"。
			#   物理上地平线附近大气最厚，楼体底部应该几乎完全溶进雾里。
			#   现在每栋楼自己按高度做 smoothstep(0.45,1.0) 渐隐到 haze，
			#   底行颜色 == 地面首行颜色，接缝在数学上连续。
			var span: int = maxi(half - top_y, 1)
			for yy: int in range(top_y, half):
				var prog: float = float(yy - top_y) / float(span)
				var row_tone: Color = tone.lerp(haze, smoothstep(0.45, 1.0, prog))
				out.fill_rect(Rect2i(x, yy, draw_w, 1), row_tone)
			# 竖向窗带（审核 P0-3 修法）：每栋楼 3~5 条，宽 2~3px、间隔 6~9px。
			# 这是让 1000px 纯色块变成"有立面的楼"的唯一手段 ——
			# 亮 0.18 的暖白窗光，在暗剪影上读成密密麻麻的窗格。
			# 窗带同样随楼体渐隐（底部被雾吃掉），否则会在雾里留下一排亮点。
			var win_tone: Color = tone.lerp(Color(1.0, 0.95, 0.75), 0.18)
			var wx: int = x + rng.randi_range(2, 6)
			while wx < x + draw_w - 3:
				var band_w: int = rng.randi_range(2, 3)
				# 窗带不到顶：顶部留 6~10px 女儿墙，否则楼像被切开
				var band_top: int = top_y + rng.randi_range(6, 10)
				if band_top < half:
					var band_span: int = maxi(half - band_top, 1)
					for yy: int in range(band_top, half):
						var prog2: float = float(yy - band_top) / float(band_span)
						var fade: float = smoothstep(0.45, 1.0, prog2)
						var cw: Color = win_tone.lerp(haze, fade)
						out.fill_rect(Rect2i(wx, yy, mini(band_w, x + draw_w - wx), 1), cw)
				wx += band_w + rng.randi_range(6, 9)
			# 楼顶受落日照射的亮边 —— 这是"楼"与"色块"的唯一区分特征
			var rim: Color = Color(
				minf(tone.r * 1.55 + 0.10, 1.0),
				minf(tone.g * 1.42 + 0.08, 1.0),
				minf(tone.b * 1.26 + 0.06, 1.0))
			out.fill_rect(Rect2i(x, top_y, draw_w, 1), rim)
			# 楼间缝隙：露出后面天空，宽 2~9px（窄缝才像密集天际线）
			var gap: int = rng.randi_range(2, 9)
			x += w + gap

## 高空俯视的城市地面。
##
## 两版都画成「砖墙」的教训（目视成品确认）：
##   ① 每条带末尾画**贯穿全宽**的横向街道线 → 砖墙横缝；
##   ② 带内纵向缝隙等宽、行距固定 → 砖墙竖缝；
##   ③ 整体用 haze（橙色）当底色 → 整片橙砖。
## 只要还在「轴对齐矩形 + 固定行距」的画法里，怎么调参数都是砖 —— 这是画法的必然。
##
## 物理事实：站在 48 层看下方城市，绝大部分被大气散射吃掉，只有
##   ① 地平线附近一层极低对比的远楼剪影 ② 大片柔和雾霭渐变。
## 所以正确画法是「宽雾化渐变 + 低频亮度扰动」，不是「画街区」。
func _paint_city_ground(out: Image, half: int, haze: Color, far: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125
	var ground_h: int = OUT_H - half

	# 底色：地平线暖雾 → 近处冷灰。指数 0.30 让过渡集中在顶部，
	# 下半大部分是稳定的深灰（城市被雾吃掉后的样子）。
	# pow(t,0.30) → smoothstep(0.0,0.35,t)（ch04 审核 P0-4 修法）：
	#   pow 曲线在 t=0 处导数无穷，512 行附近一跨过地平线就立刻掉进深灰，
	#   与雾化带末尾的 haze 色接不上，形成"暗→爆亮→暗"三明治。
	#   smoothstep(0,0.35) 让前 35% 高度基本保持 haze 色，之后才过渡到 cool。
	# 底色：地平线暖雾 → 近处冷灰。
	# 过渡带必须**足够长**（smoothstep 0→0.45，即前 230 行）：
	#   若像初版那样用 pow(t,0.30) 在前 35% 就压到 cool，
	#   地面顶部几行与楼群底边色差过大，会读成地平线硬切。
	# cool 0.090 → 0.150（第三轮）：0.090 在 sRGB 里只有 ~40 级，
	#   读成"脚下是黑色虚空"，不像 48 层俯瞰的城市地面。
	var cool := Color(0.150, 0.152, 0.168)
	for y: int in range(half, OUT_H):
		var t: float = float(y - half) / float(maxi(ground_h - 1, 1))
		out.fill_rect(Rect2i(0, y, OUT_W, 1), haze.lerp(cool, smoothstep(0.0, 0.45, t)))

	# 低频亮度扰动：用大尺寸、软边的椭圆叠出"云状"不均匀。
	#
	# 硬边矩形 → 软边椭圆（第三轮修正，目视成品确认）：
	#   上一版用 `_blend_rect`（矩形内均匀偏移、边界硬切）叠 260 个 120~420px 方块，
	#   在 512px 高的下半里必然读成马赛克棋盘 —— 每个矩形都是一块清晰的方块，
	#   与"大气密度差"毫无关系。这不是参数问题，是"硬边矩形"这个画法的必然结果。
	#   改成椭圆 + 平方衰减边缘（中心 1.0、边缘 0.0），重叠处自然融成雾团。
	for i: int in range(220):
		var bw: int = rng.randi_range(120, 420)
		var bh: int = rng.randi_range(60, 200)
		var bx: int = rng.randi_range(-bw / 2, OUT_W)
		# 越靠近地平线扰动越明显（远处大气更厚）
		var by: int = half + int(pow(rng.randf(), 1.6) * float(ground_h))
		var lift: float = rng.randf_range(-0.030, 0.030)
		_blend_ellipse(out, bx + bw / 2, by + bh / 2, bw / 2, bh / 2, lift, 0.55)

	# 地平线下方一排远楼剪影：极低对比（比雾只暗 6~10 级），
	# 只在顶部 70px 内出现 —— 这是"城市"的唯一暗示，不能画实。
	for i: int in range(90):
		var w: int = rng.randi_range(18, 64)
		var h: int = rng.randi_range(8, 30)
		var x: int = rng.randi_range(0, OUT_W - w)
		var tone := Color(
			maxf(haze.r * 0.86, 0.0),
			maxf(haze.g * 0.84, 0.0),
			maxf(haze.b * 0.86, 0.0))
		# 半透明叠加，让剪影融进雾里
		_blend_rect_solid(out, Rect2i(x, half + rng.randi_range(2, 46), w, h), tone, 0.30)

## 在 (cx,cy) 为中心的椭圆内叠加亮度偏移，边缘用平方衰减软过渡。
## 硬边矩形是上一版马赛克的根源，这里必须用软边。
func _blend_ellipse(out: Image, cx: int, cy: int, rx: int, ry: int,
		lift: float, alpha: float) -> void:
	var x0: int = maxi(cx - rx, 0)
	var y0: int = maxi(cy - ry, 0)
	var x1: int = mini(cx + rx, out.get_width())
	var y1: int = mini(cy + ry, out.get_height())
	var rx2: float = float(maxi(rx, 1))
	var ry2: float = float(maxi(ry, 1))
	for y: int in range(y0, y1):
		var ny: float = float(y - cy) / ry2
		for x: int in range(x0, x1):
			var nx: float = float(x - cx) / rx2
			var d2: float = nx * nx + ny * ny
			if d2 >= 1.0:
				continue
			# 中心 1.0、边缘 0.0 的软权重
			var wgt: float = 1.0 - d2
			var c := out.get_pixel(x, y)
			var dv: float = lift * alpha * wgt
			out.set_pixel(x, y, Color(
				clampf(c.r + dv, 0.0, 1.0),
				clampf(c.g + dv, 0.0, 1.0),
				clampf(c.b + dv, 0.0, 1.0)))

## 在 rect 内叠加一个均匀亮度偏移（lift 可正可负），alpha 控制强度。
func _blend_rect(out: Image, rect: Rect2i, lift: float, alpha: float) -> void:
	var x0: int = maxi(rect.position.x, 0)
	var y0: int = maxi(rect.position.y, 0)
	var x1: int = mini(rect.position.x + rect.size.x, out.get_width())
	var y1: int = mini(rect.position.y + rect.size.y, out.get_height())
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(
				clampf(c.r + lift * alpha, 0.0, 1.0),
				clampf(c.g + lift * alpha, 0.0, 1.0),
				clampf(c.b + lift * alpha, 0.0, 1.0)))

## 用 tone 按 alpha 混进 rect（用于剪影）。
func _blend_rect_solid(out: Image, rect: Rect2i, tone: Color, alpha: float) -> void:
	var x0: int = maxi(rect.position.x, 0)
	var y0: int = maxi(rect.position.y, 0)
	var x1: int = mini(rect.position.x + rect.size.x, out.get_width())
	var y1: int = mini(rect.position.y + rect.size.y, out.get_height())
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, c.lerp(tone, alpha))

## 地平线雾化带：把天空/楼群/城市三段的接缝一起抹平。
##
## 两次修正的完整推理（都被目视成品确认）：
##   ① `a = t*t`（原版）：二次曲线中段权重只有 0.25，压不住城市底色，
##      实测整行均值 y=498 L=0.213 → y=512 L=0.466，14 行内反弹 0.253。
##   ② `a = smoothstep(0,1,t)` 且带从 half-56 起：权重单调递增到带尾的 0.90，
##      **下一行直接回到 0** —— 带尾自己变成一条横贯全宽的亮带硬边。
##      这是"只在带内混合、带外不混合"这个画法的必然结果，改曲线救不了。
##   ③ 正解：**两端都渐隐的钟形权重**，且带跨过地平线（上盖楼群底边、下盖城市顶部）。
##      升起段 half-40..half+23，保持段到 half+59，再渐隐到 half+140。
##      任何一行与相邻行的 alpha 差都 ≤0.04，不可能读出边。
func _paint_haze(out: Image, half: int, haze: Color) -> void:
	var y0: int = half - 40
	var span: int = HAZE_PX + 84
	for i: int in range(span):
		var y: int = y0 + i
		if y < 0 or y >= out.get_height():
			continue
		var t: float = float(i) / float(maxi(span - 1, 1))
		# 钟形：smoothstep 升起 → 平台 → smoothstep 落回 0
		var a: float = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.55, 1.0, t)) * 0.92
		for x: int in range(out.get_width()):
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, c.lerp(haze, a))

## 落日盘：固定位置、固定半径、圆对称，完全不依赖源图。
##
## 位置推导：审核实测源图太阳盘在 v=0.249、u=0.6899，对应输出 (1413, 255)；
##   elev = (512-255)/512*90 = 45.2°，与 with_sky 的 200° 旋转配合后
##   正好落在玩家出生朝向（-Z）偏右。
## 半径 34px ≈ 6° 视角 —— 真实太阳只有 0.53°，但游戏里必须放大才读得出"太阳"。
func _paint_sun(out: Image, half: int) -> void:
	var cx: int = int(float(OUT_W) * 0.69)
	var cy: int = int(float(OUT_H) * 0.249)
	var r_max: int = 34
	for r: int in range(r_max, 0, -1):
		var t: float = float(r) / float(r_max)
		# 外圈几乎透明，内圈实心；1-t^2 让边缘衰减更自然
		var a: float = (1.0 - t * t) * 0.85
		var tone := Color(1.0, 0.95, 0.80)
		_blend_circle(out, cx, cy, r, tone, a)

## 在 (cx,cy) 画一个半径 r 的实心圆，按 alpha 混色。
func _blend_circle(out: Image, cx: int, cy: int, r: int, tone: Color, alpha: float) -> void:
	var r2: int = r * r
	for dy: int in range(-r, r + 1):
		var y: int = cy + dy
		if y < 0 or y >= out.get_height():
			continue
		for dx: int in range(-r, r + 1):
			if dx * dx + dy * dy > r2:
				continue
			var x: int = cx + dx
			if x < 0:
				x += out.get_width()
			elif x >= out.get_width():
				x -= out.get_width()
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, c.lerp(tone, alpha))

## 首尾接缝混合：把最右 seam 列渐变到最左 seam 列，反之亦然。
## 只混 seam 宽度的像素，中间不动 —— 否则会把整张图抹成一片。
func _blend_seam(out: Image, seam: int) -> void:
	var w: int = out.get_width()
	var h: int = out.get_height()
	if seam * 2 >= w:
		return
	for y: int in range(h):
		# 取两端各自的边界色作为混合端点
		var left := out.get_pixel(0, y)
		var right := out.get_pixel(w - 1, y)
		for i: int in range(seam):
			var t: float = float(i) / float(seam)
			# 左端：从 right 渐变到 left（i=0 时最接近 right，与 w-1 连续）
			var cl := out.get_pixel(i, y)
			out.set_pixel(i, y, cl.lerp(right, 1.0 - t))
			# 右端：从 left 渐变到 right（i=0 时最接近 left，与 0 连续）
			var cr := out.get_pixel(w - 1 - i, y)
			out.set_pixel(w - 1 - i, y, cr.lerp(left, 1.0 - t))

## 行内亮度方差：衡量该行沿 x 方向有没有结构（街区/街道交错）。
## 纯垂直渐变 = 0；有街区 = 明显大于 0。
func _row_horizontal_var(img: Image, y: int) -> float:
	if y <= 0 or y >= img.get_height():
		return 0.0
	var w: int = img.get_width()
	var sum: float = 0.0
	var sum2: float = 0.0
	var n: int = 0
	for x: int in range(0, w, 2):
		var c := img.get_pixel(x, y)
		var l: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		sum += l
		sum2 += l * l
		n += 1
	if n < 2:
		return 0.0
	var mean: float = sum / float(n)
	return sum2 / float(n) - mean * mean

## 该行里亮度低于阈值的像素占比：用于确认地平线以上真的画了楼体（暗于天空）。
func _dark_ratio(img: Image, y: int, thresh: float) -> float:
	if y <= 0 or y >= img.get_height():
		return 0.0
	var n: int = 0
	var dark: int = 0
	for x: int in range(0, img.get_width(), 2):
		var c := img.get_pixel(x, y)
		var l: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		if l < thresh:
			dark += 1
		n += 1
	return float(dark) / float(maxi(n, 1))

## 相邻行平均色差：衡量该行附近有没有水平结构。纯渐变会接近 0。
func _edge_energy(img: Image, y: int) -> float:
	if y <= 0 or y >= img.get_height():
		return 0.0
	var a := _row_mean(img, y - 1)
	var b := _row_mean(img, y)
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

## 地平线 = 相邻两行平均色差最大的那一行。落日天空渐变平缓，地面是纯色块，跳变极明显。
func _find_horizon(img: Image) -> int:
	var h: int = img.get_height()
	var best: float = -1.0
	var best_row: int = h / 2
	for y: int in range(1, h - 1):
		var d: float = _edge_energy(img, y)
		if d > best:
			best = d
			best_row = y
	return clampi(best_row, int(h * 0.05), int(h * 0.95))

func _row_mean(img: Image, y: int) -> Color:
	var w: int = img.get_width()
	var n: int = 0
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	for x: int in range(0, w, 4):
		var c := img.get_pixel(x, y)
		r += c.r
		g += c.g
		b += c.b
		n += 1
	if n == 0:
		return Color.BLACK
	return Color(r / n, g / n, b / n)
