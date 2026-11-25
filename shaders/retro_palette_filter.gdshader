// =============================================================================
// retro_palette_filter.gdshader
// =============================================================================
// shader_type : canvas_item（全屏调色板滤镜）
//
// 适用节点
//   - 独立调色板滤镜，按 PDF「复古 CRT 或调色板滤镜按风格要求取舍」的取舍原则设计：
//     pixelzombie_postprocess 已负责像素化 + 量化 + CRT，本滤镜不再重复那三项，
//     只做「色调情绪」：三段色带映射 + 色温偏移 + 胶片颗粒 + 轻微暗角。
//   - 挂法：窗口级 CanvasLayer 下的全屏 ColorRect（anchors 全 0/1，mouse_filter IGNORE），
//     材质用本 ShaderMaterial，位于 3D 场景之上。需要 hint_screen_texture 读到下层画面。
//   - 用法定位（PDF 五段式节奏的情绪切换）：
//       安全屋整备 / 剧情过场  filter_strength = 0.5~0.7，暖黄褪色
//       推进段 / 事件段        filter_strength = 0.0~0.15，几乎不干预
//       尸潮 / BOSS 段         filter_strength = 0.35，冷青压暗 + 颗粒加重
//     脚本用 tween 平滑过渡，不要瞬切。
//
// 功能
//   1. 三段色带映射（shadow / mid / high），复古像素调色板质感
//   2. 高亮点缀色（血色高光），只在极亮处轻微触发，保持克制
//   3. 色温偏移 warmth（负=冷，正=暖）
//   4. 动态胶片颗粒（TIME 驱动，颗粒强度可调）
//   5. 与主后期不冲突：不量化、不像素化、不扫描线
//
// 兼容性
//   Godot 4.x / Compatibility(gl_compatibility) 渲染器可用。
//
// uniform 说明与推荐值
//   screen_texture   屏幕来源，引擎自动填充。
//   filter_strength  混入强度 0~1。推荐战斗 0.0、安全屋 0.6、尸潮 0.35。
//   color_shadow     暗部色（source_color）。推荐 vec3(0.05, 0.06, 0.10) 冷夜蓝黑。
//   color_mid        中间调（source_color）。推荐 vec3(0.34, 0.37, 0.42)。
//   color_high       亮部（source_color）。推荐 vec3(0.85, 0.82, 0.70) 旧日暖黄。
//   color_accent     点缀色（source_color）。推荐 vec3(0.55, 0.12, 0.10) 血色高光。
//   accent_threshold 点缀色触发亮度阈值 0.5~1.0。推荐 0.78。
//   accent_amount    点缀色混入量 0~1。推荐 0.30。
//   grain_strength   胶片颗粒 0~0.2。推荐 0.05；尸潮段可 0.10。
//   warmth           色温 -1~1。推荐 0.15（微暖）；地下实验室章节用 -0.2。
//   vignette         暗角 0~1。推荐 0.25（主后期已有暗角时用 0.0 避免叠加过暗）。
// =============================================================================
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float filter_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec3 color_shadow : source_color = vec3(0.05, 0.06, 0.10);
uniform vec3 color_mid : source_color = vec3(0.34, 0.37, 0.42);
uniform vec3 color_high : source_color = vec3(0.85, 0.82, 0.70);
uniform vec3 color_accent : source_color = vec3(0.55, 0.12, 0.10);
uniform float accent_threshold : hint_range(0.5, 1.0) = 0.78;
uniform float accent_amount : hint_range(0.0, 1.0) = 0.30;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.05;
uniform float warmth : hint_range(-1.0, 1.0) = 0.15;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;

// 时间驱动的胶片颗粒；乘 913 让颗粒落在亚像素尺度，避免成块
float grain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + TIME * 61.7) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));

	// 三段色带映射：shadow -> mid -> high
	vec3 graded;
	if (luma < 0.5) {
		graded = mix(color_shadow, color_mid, luma * 2.0);
	} else {
		graded = mix(color_mid, color_high, (luma - 0.5) * 2.0);
	}

	// 高亮处轻微混入点缀色（血色高光），克制触发
	float accent = smoothstep(accent_threshold, 1.0, luma);
	graded = mix(graded, color_accent, accent * accent_amount);

	// 保留一部分原始饱和度信息，避免色带把画面压成死灰
	float graded_luma = dot(graded, vec3(0.299, 0.587, 0.114));
	graded = mix(vec3(graded_luma), graded, 1.15);

	// 色温偏移：暖加红减蓝，冷反之
	graded.r += warmth * 0.08;
	graded.b -= warmth * 0.08;

	// 与原画面按强度混合
	col = mix(col, graded, clamp(filter_strength, 0.0, 1.0));

	// 暗角（主后期已带暗角时把 vignette 设 0）
	if (vignette > 0.0) {
		vec2 vc = SCREEN_UV - 0.5;
		col *= clamp(1.0 - dot(vc, vc) * vignette * 1.6, 0.0, 1.0);
	}

	// 胶片颗粒：强度也随 filter_strength 缩放，强度为 0 时完全不干扰原画面
	col += (grain_hash(SCREEN_UV * 913.0) - 0.5) * grain_strength * filter_strength;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
