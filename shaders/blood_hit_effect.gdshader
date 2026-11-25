// =============================================================================
// blood_hit_effect.gdshader
// =============================================================================
// shader_type : spatial
//
// 适用节点（3D 世界里的血液特效）
//   - Sprite3D / AnimatedSprite3D 的 material_override：空中血雾、喷溅、地面血渍。
//   - 必须用 spatial：canvas_item 挂 Sprite3D 会渲染成灰块（3D 管线不给它绑 TEXTURE）。
//     贴图通过 albedo_texture 显式传入：mat.set_shader_parameter("albedo_texture", tex)
//   - 地面血渍：同一个着色器，Sprite3D 绕 X 轴转 -90° 平铺地面、关掉 billboard，
//     darken_only = true，靠"向暗色混合"实现压暗，不破坏地砖明暗。
//   - 动画帧：用 AnimatedSprite3D + SpriteFrames，或 Sprite3D 开 region_enabled
//     逐帧改 region_rect。不要在着色器里切图集（会拉扁四边形）。
//   - HUD 层血溅（贴屏幕的 2D 血渍）用 blood_hit_effect_2d.gdshader。
//
// 功能（对应 PDF「血腥表现克制写实」+ pixelfx 调色板换色要求）
//   1. 把 pixelfx 导出的任意颜色血液帧统一重映射到低饱和暗红（不改素材，只改 uniform）
//   2. 保留原帧的明暗层次，避免像素颗粒被抹平
//   3. 生命周期淡出：alpha 衰减 + 低浓度像素裁掉，形成颗粒状消散而非整体变透明
//   4. darken_only 模式：只压暗不染色，用于地面血渍
//
// 兼容性
//   Godot 4.x / Compatibility(gl_compatibility)。blend_mix + 硬边裁剪。
//
// uniform 说明与推荐值
//   albedo_texture   血液帧贴图。脚本必须绑定；未绑定为白（调试可见）。
//   sprite_size      贴图像素尺寸 vec2。推荐 32x32 或 64x64（pixelfx 常用档）。
//   flip_h           水平翻转，复用同一套帧做左右两侧喷溅。
//   blood_color      主血色（source_color）。推荐 (0.42, 0.06, 0.05, 1.0)。
//   blood_dark       暗部血色（source_color）。推荐 (0.16, 0.02, 0.02, 1.0)。
//   fade             生命周期进度 0~1，脚本从 0 递增。推荐总时长 0.25~0.45 秒。
//   saturation_mul   饱和度系数 0~1。推荐 0.65（低饱和，PDF 克制写实）。
//   intensity        亮度倍率 0~2。推荐 1.0；喷溅瞬间可 1.3。
//   darken_only      true = 只压暗（地面血渍）；false = 染色（空中血雾）。
//   glow             叠加高光 0~1。推荐 0.0；要"湿"的反光用 0.15。
//   dissolve_power   消散曲线指数 0.5~4。推荐 1.0 线性；2.0 后段碎得更快。
//   alpha_cutoff     硬边裁剪阈值 0~1。推荐 0.5。
// =============================================================================
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform vec2 sprite_size = vec2(32.0, 32.0);
uniform bool flip_h = false;

uniform vec4 blood_color : source_color = vec4(0.42, 0.06, 0.05, 1.0);
uniform vec4 blood_dark : source_color = vec4(0.16, 0.02, 0.02, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float saturation_mul : hint_range(0.0, 1.0) = 0.65;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool darken_only = false;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_power : hint_range(0.5, 4.0) = 1.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

vec2 sample_uv(vec2 local) {
	vec2 l = clamp(local, vec2(0.0), vec2(1.0));
	if (flip_h) {
		l.x = 1.0 - l.x;
	}
	return l;
}

void fragment() {
	vec4 base = texture(albedo_texture, sample_uv(UV));

	// 生命周期进度，指数塑形
	float f = pow(clamp(fade, 0.0, 1.0), dissolve_power);

	// 原图亮度作为血浆浓度权重（保住 pixelfx 帧的层次）
	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col;

	if (darken_only) {
		// 地面血渍：只压暗，保留底层明暗结构
		col = blood_dark.rgb * (0.45 + luma * 0.55);
	} else {
		// 空中血雾：按亮度在暗部与主色间插值，再压饱和度
		vec3 blood = mix(blood_dark.rgb, blood_color.rgb, clamp(luma * 1.7, 0.0, 1.0));
		float bl = dot(blood, vec3(0.299, 0.587, 0.114));
		blood = mix(vec3(bl), blood, saturation_mul);
		col = blood * (0.40 + luma * 0.85);
	}

	col *= intensity;
	col += blood_color.rgb * glow;

	// 淡出：alpha 衰减 + 低浓度像素整块裁掉 -> 颗粒状消散
	float alpha = base.a * (1.0 - f);
	if (alpha < f * 0.30 || alpha < alpha_cutoff * (1.0 - f)) {
		discard;
	}

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ALPHA = alpha;
}
