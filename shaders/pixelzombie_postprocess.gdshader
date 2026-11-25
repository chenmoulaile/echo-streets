// =============================================================================
// pixelzombie_postprocess.gdshader
// =============================================================================
// shader_type : canvas_item（全屏后期处理）
//
// 适用节点
//   - 路线 A（PDF 正统低分渲染）：放在 SubViewport(480x270) 内部的 CanvasLayer 上，
//     节点用铺满的 ColorRect（anchors 全 0/1，mouse_filter = IGNORE），挂 ShaderMaterial。
//     此时 pixel_size 保持 1.0，像素颗粒由 SubViewport 分辨率 + 整数倍放大提供，
//     本着色器只负责量化 / 抖动 / CRT / 调色。
//   - 路线 B（无 SubViewport 的直出后期）：挂在窗口级 CanvasLayer 的全屏 ColorRect 上，
//     pixel_size 设为 4.0（1920x1080 / 480x270 = 4），用采样对齐模拟低分画面。
//   - 必须位于绘制 3D 场景之上的 CanvasLayer，hint_screen_texture 才能读到 3D 画面。
//
// 功能（对应 PDF「Doom 式伪 3D 画面底座」与「克制写实的低饱和色调」）
//   1. 低分辨率像素块对齐采样（像素丧尸风格核心）
//   2. 每通道调色板量化 + 4x4 Bayer 有序抖动（复古色深，PDF 全局 16~32 色一致性要求）
//   3. 可选 CRT：桶形曲率、水平色差、硬扫描线、暗角
//   4. 饱和度 / 对比度 / 亮度 / 黑位微调
//
// 兼容性
//   Godot 4.x，Compatibility(gl_compatibility) 渲染器可用。
//   hint_screen_texture 在 Compatibility 下由引擎自动插入一次 backbuffer 拷贝（每帧一次，
//   可接受）。Bayer 值用算术递推生成，不用矩阵动态索引，避免 GLES3 / SPIR-V 兼容问题。
//
// uniform 说明与推荐值
//   screen_texture        屏幕来源纹理，引擎自动填充，不要脚本赋值。
//   pixel_size            像素块边长（屏幕像素）。路线 A 用 1.0；路线 B 用 4.0（480x270 的 4 倍）。
//   palette_levels        每通道色阶数。推荐 8.0（8^3=512 色）；更硬核可用 5.0~6.0。
//   dither_strength       抖动强度，1.0 = 刚好覆盖一个量化台阶。推荐 1.0，0 关闭。
//   saturation            饱和度。推荐 0.85（克制低饱和，PDF 血腥写实基调）。
//   contrast              对比度。推荐 1.06。
//   brightness            亮度。推荐 1.0。
//   lift                  黑位抬升（-0.5~0.5）。推荐 0.0；要"褪色胶片"感用 0.03。
//   enable_crt            CRT 总开关。推荐 true，可整体关掉只留像素化。
//   curvature             桶形曲率。推荐 0.06（0.0 关闭，>0.15 会明显变形影响瞄准）。
//   chromatic_aberration  水平色差偏移，单位为低分像素。推荐 1.0，0 关闭。
//   scanline_strength     扫描线强度。推荐 0.18。
//   scanline_height       扫描线周期，单位为低分像素行。推荐 1.0（逐行交替）。
//   vignette_strength     暗角强度。推荐 0.35。
// =============================================================================
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float pixel_size : hint_range(1.0, 16.0) = 1.0;
uniform float palette_levels : hint_range(2.0, 32.0) = 8.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 0.85;
uniform float contrast : hint_range(0.0, 2.0) = 1.06;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float lift : hint_range(-0.5, 0.5) = 0.0;
uniform bool enable_crt = true;
uniform float curvature : hint_range(0.0, 0.5) = 0.06;
uniform float chromatic_aberration : hint_range(0.0, 8.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float scanline_height : hint_range(1.0, 8.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

// 2x2 Bayer 基元，返回 M2[x][y]/4，取值 {0, 0.25, 0.5, 0.75}
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

// 4x4 Bayer 递推：M4 = 4*M2[低两位] + M2[高两位]，归一到 0..1
float bayer4(vec2 p) {
	p = mod(floor(p), 4.0);
	return bayer2(p) + bayer2(floor(p * 0.5)) * 0.25;
}

// 桶形曲率：边缘向外扩张采样坐标 -> 画面向内收缩，留出 CRT 黑边
vec2 apply_curvature(vec2 uv, float amount) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + amount * dot(c, c) * 0.5;
	return c * 0.5 + 0.5;
}

// 主体逻辑放在辅助函数里：Godot 4 禁止在 fragment() 内使用 return。
// SCREEN_PIXEL_SIZE 只在 fragment() 作用域可见，必须由调用方作为参数传入。
vec4 shade_post(vec2 frag_pixel, vec2 screen_pixel) {
	// 像素块索引与块中心：同块内所有片元采样同一 UV -> 硬边像素颗粒
	vec2 block_index = floor(frag_pixel / pixel_size);
	vec2 block_center = (block_index + 0.5) * pixel_size;
	vec2 block_uv = block_center * screen_pixel;

	vec2 uv = block_uv;
	if (enable_crt && curvature > 0.0) {
		uv = apply_curvature(uv, curvature);
		// 曲率把画面推出屏幕的部分填黑，形成弧面电视边框
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0, 0.0, 0.0, 1.0);
		}
	}

	// 色差：R/B 通道沿水平方向反向偏移，偏移量以低分像素计
	vec3 col;
	if (enable_crt && chromatic_aberration > 0.0) {
		vec2 ca = vec2(chromatic_aberration * pixel_size * screen_pixel.x, 0.0);
		col.r = texture(screen_texture, clamp(uv + ca, vec2(0.0), vec2(1.0))).r;
		col.g = texture(screen_texture, uv).g;
		col.b = texture(screen_texture, clamp(uv - ca, vec2(0.0), vec2(1.0))).b;
	} else {
		col = texture(screen_texture, uv).rgb;
	}

	// 低饱和调色 + 明暗
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = (col - 0.5) * contrast + 0.5 + lift;
	col *= brightness;

	// 有序抖动 + 每通道量化（抖动按像素块索引取样，保证同块颜色一致）
	float dither = (bayer4(block_index) - 0.5) * dither_strength;
	col = floor(col * palette_levels + dither) / palette_levels;

	// 硬扫描线：按低分像素行交替压暗，与像素块严格对齐
	if (enable_crt && scanline_strength > 0.0) {
		float row = floor(frag_pixel.y / (pixel_size * max(scanline_height, 1.0)));
		col *= 1.0 - scanline_strength * mod(row, 2.0);
	}

	// 暗角
	if (vignette_strength > 0.0) {
		vec2 vc = block_uv - 0.5;
		float vig = 1.0 - dot(vc, vc) * vignette_strength * 1.6;
		col *= clamp(vig, 0.0, 1.0);
	}

	return vec4(clamp(col, 0.0, 1.0), 1.0);
}

void fragment() {
	// 当前视口一个像素对应的 UV 步长（SubViewport 路线下即 480x270 的步长）
	COLOR = shade_post(FRAGCOORD.xy, SCREEN_PIXEL_SIZE);
}
