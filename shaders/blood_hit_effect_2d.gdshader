// =============================================================================
// blood_hit_effect_2d.gdshader
// =============================================================================
// shader_type : canvas_item
//
// 适用节点（2D 层血液特效）
//   - Sprite2D / AnimatedSprite2D / TextureRect 的 material 或 material_override。
//   - 用于：贴屏幕的 HUD 血溅、2D 关卡的血迹贴花、菜单里的血腥装饰。
//   - 3D 世界（Sprite3D 血雾 / 地面血渍）请用 blood_hit_effect.gdshader（spatial 版）。
//
// 与 spatial 版的差别
//   直接使用引擎内置 TEXTURE / TEXTURE_PIXEL_SIZE，挂上即生效，无需脚本绑贴图。
//   参数语义完全一致（fade / darken_only / saturation_mul / intensity 等）。
//
// 兼容性
//   Godot 4.x / Compatibility(gl_compatibility)。
//   alpha 阈值裁剪出颗粒状消散，不额外采样。
//
// uniform 说明与推荐值
//   blood_color      主血色（source_color）。推荐 (0.42, 0.06, 0.05, 1.0)。
//   blood_dark       暗部血色（source_color）。推荐 (0.16, 0.02, 0.02, 1.0)。
//   fade             生命周期进度 0~1，脚本从 0 递增。推荐总时长 0.25~0.45 秒。
//   saturation_mul   饱和度系数 0~1。推荐 0.65。
//   intensity        亮度倍率 0~2。推荐 1.0。
//   darken_only      true = 只压暗（地面/墙面血渍）；false = 染色（空中血雾）。
//   glow             叠加高光 0~1。推荐 0.0。
//   dissolve_power   消散曲线指数 0.5~4。推荐 1.0。
// =============================================================================
shader_type canvas_item;
render_mode unshaded;

uniform vec4 blood_color : source_color = vec4(0.42, 0.06, 0.05, 1.0);
uniform vec4 blood_dark : source_color = vec4(0.16, 0.02, 0.02, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float saturation_mul : hint_range(0.0, 1.0) = 0.65;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool darken_only = false;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_power : hint_range(0.5, 4.0) = 1.0;

// Godot 4 禁止在 fragment() 内使用 return，主体逻辑放辅助函数。
vec4 shade_blood(vec4 base) {
	// 透明像素直接透出，保持像素硬边
	if (base.a < 0.01) {
		return base;
	}

	// 原图亮度作为血浆浓度权重
	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col;

	if (darken_only) {
		// 血渍：只按原图形状压暗，保留底层明暗
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

	// 生命周期淡出：alpha 衰减 + 低浓度像素裁掉，形成颗粒状消散
	float f = pow(clamp(fade, 0.0, 1.0), dissolve_power);
	float alpha = base.a * (1.0 - f);
	if (alpha < f * 0.30) {
		alpha = 0.0;
	}

	return vec4(clamp(col, 0.0, 1.0), alpha);
}

void fragment() {
	COLOR = shade_blood(texture(TEXTURE, UV));
}
