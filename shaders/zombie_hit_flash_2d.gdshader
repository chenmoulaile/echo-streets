// =============================================================================
// zombie_hit_flash_2d.gdshader
// =============================================================================
// shader_type : canvas_item
//
// 适用节点（纯 2D 场景 / HUD 层）
//   - Sprite2D、AnimatedSprite2D、TextureRect 的 material 或 material_override。
//   - 用于：HUD 里的敌人血条图标受击闪烁、2D 小地图上的丧尸红点、教程关的 2D 演示。
//   - 3D 世界里的丧尸纸片人请用 zombie_hit_flash.gdshader（spatial 版），
//     因为 canvas_item 挂 Sprite3D 拿不到贴图，只会渲染成灰块。
//
// 与 spatial 版的差别
//   2D 版本可以直接用引擎内置的 TEXTURE / TEXTURE_PIXEL_SIZE，
//   不需要脚本绑定贴图、不需要手写图集 UV，挂上去就生效。
//   其余闪白 / 边缘 / 染色参数语义与 spatial 版完全一致，可共用同一套调参经验。
//
// 兼容性
//   Godot 4.x / Compatibility(gl_compatibility)。
//   透明像素 early-out，不产生额外采样。
//
// uniform 说明与推荐值
//   flash_amount   闪白强度 0~1，脚本驱动。推荐峰值 1.0，衰减 0.10~0.14 秒。
//   flash_color    闪白颜色（source_color）。推荐纯白 (1,1,1,1)。
//   tint_color     状态染色（source_color）。推荐血红 (0.55, 0.06, 0.05, 1.0)。
//   tint_amount    染色强度 0~1。推荐 0.0；爆头瞬间可 0.5。
//   overexposure   过曝增益 0~1。推荐 0.25；无泛光用 0.0。
//   rim_boost      边缘提亮 0~1。推荐 0.35；怕脏用 0.0。
//   flash_power    闪白曲线指数 0.5~4。推荐 1.0；2.0 更"扎手"。
// =============================================================================
shader_type canvas_item;
render_mode unshaded;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(0.55, 0.06, 0.05, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float overexposure : hint_range(0.0, 1.0) = 0.25;
uniform float rim_boost : hint_range(0.0, 1.0) = 0.35;
uniform float flash_power : hint_range(0.5, 4.0) = 1.0;

// Godot 4 禁止在 fragment() 内使用 return，主体逻辑放辅助函数。
// TEXTURE / TEXTURE_PIXEL_SIZE 是 fragment() 作用域内置，必须作为参数传入。
vec4 shade_hit(sampler2D tex, vec4 base, vec2 uv, vec2 texel) {
	// 透明像素不参与运算，直接透出
	if (base.a < 0.01) {
		return base;
	}

	vec3 col = base.rgb;

	// 状态染色（默认关闭）
	if (tint_amount > 0.0) {
		col = mix(col, tint_color.rgb, tint_amount);
	}

	// 闪白强度曲线
	float amount = pow(clamp(flash_amount, 0.0, 1.0), flash_power);

	// 边缘提亮：本像素不透明而四邻域透明处即轮廓
	if (rim_boost > 0.0 && amount > 0.0) {
		float a_l = texture(tex, uv - vec2(texel.x, 0.0)).a;
		float a_r = texture(tex, uv + vec2(texel.x, 0.0)).a;
		float a_u = texture(tex, uv - vec2(0.0, texel.y)).a;
		float a_d = texture(tex, uv + vec2(0.0, texel.y)).a;
		float edge = 1.0 - min(min(a_l, a_r), min(a_u, a_d));
		col += flash_color.rgb * edge * rim_boost * amount;
	}

	// 主体闪白 + 过曝
	col = mix(col, flash_color.rgb, amount);
	col += flash_color.rgb * amount * overexposure;

	return vec4(clamp(col, 0.0, 1.0), base.a);
}

void fragment() {
	COLOR = shade_hit(TEXTURE, texture(TEXTURE, UV), UV, TEXTURE_PIXEL_SIZE);
}
