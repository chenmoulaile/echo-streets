// =============================================================================
// zombie_hit_flash.gdshader
// =============================================================================
// shader_type : spatial
//
// 适用节点（3D 世界里的丧尸纸片人）
//   - Sprite3D / AnimatedSprite3D 的 material_override（挂 ShaderMaterial）。
//   - 必须用 spatial：实测 canvas_item 着色器挂到 Sprite3D 上只能渲染成灰块，
//     因为 3D 管线不会把 sprite 贴图绑到 canvas_item 的 TEXTURE 上。
//   - 因此贴图通过 albedo_texture 这个 uniform 显式传入，脚本里赋值一次：
//       mat.set_shader_parameter("albedo_texture", sprite.texture)
//   - 多帧（8 方向 / 行走序列）不要在本着色器里切图集：
//     Sprite3D 的四边形长宽比跟整张贴图走，在图集里切帧会把帧横向拉扁。
//     用 AnimatedSprite3D + SpriteFrames（每帧自动设 region，UV 仍是 0..1），
//     或 Sprite3D 开 region_enabled 并逐帧改 region_rect。
//     此时 albedo_texture 重新绑一次当前贴图即可，UV 无需任何处理。
//   - 纯 2D（Sprite2D / HUD）用 zombie_hit_flash_2d.gdshader。
//
// 功能（对应 PDF Phase 1「灰盒手感闭环」的受击闪白）
//   1. 受击闪白：向 flash_color 混合，峰值接近纯白剪影，保留像素硬边轮廓
//   2. 边缘强化：只提亮不透明像素的外轮廓，让纸片人受击时轮廓更"炸"
//   3. 过曝 punch：flash_amount 高时额外叠亮度，供后期泛光/CRT 提取
//   4. 可选染色：爆头 / 燃烧 / 中毒等状态提示（默认关闭，符合「克制写实」基调）
//   5. 左右翻转：复用同一套帧做朝向，省一半美术量（PDF 的省图方案）
//
// 兼容性
//   Godot 4.x / Compatibility(gl_compatibility)。
//   render_mode 用 depth_draw_opaque + discard：像素画没有半透明像素，
//   硬边裁剪后走不透明管线，同屏 60 只丧尸无排序开销、无混合开销。
//
// uniform 说明与推荐值
//   albedo_texture   精灵贴图。脚本必须绑定；未绑定时为白（呈纯白剪影，可用于调试）。
//   sprite_size      单帧像素尺寸 vec2。推荐填贴图实际像素（如 48x64 / 64x64）。
//                    只用于计算边缘提亮的采样步长，不影响 UV 映射。
//   flip_h           水平翻转。对应 PDF「单方向 + 左右翻转」的省图方案。
//   flash_amount     闪白强度 0~1，脚本驱动。推荐峰值 1.0，衰减 0.10~0.14 秒。
//   flash_color      闪白颜色（source_color）。推荐纯白 (1,1,1,1)；
//                    要暖白打击感用 (1.0, 0.96, 0.88, 1.0)。
//   tint_color       状态染色（source_color）。推荐血红 (0.55, 0.06, 0.05, 1.0)。
//   tint_amount      染色强度 0~1。推荐 0.0；爆头瞬间可推到 0.5。
//   overexposure     过曝增益 0~1。推荐 0.25；无泛光的 Compatibility 用 0.0。
//   rim_boost        边缘提亮 0~1。推荐 0.35；怕脏可用 0.0。
//   flash_power      闪白曲线指数 0.5~4。推荐 1.0 线性；2.0 让衰减更"扎手"。
//   alpha_cutoff     硬边裁剪阈值 0~1。推荐 0.5（像素画标准）；0.1 保留软边。
// =============================================================================
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform vec2 sprite_size = vec2(64.0, 64.0);
uniform bool flip_h = false;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(0.55, 0.06, 0.05, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float overexposure : hint_range(0.0, 1.0) = 0.25;
uniform float rim_boost : hint_range(0.0, 1.0) = 0.35;
uniform float flash_power : hint_range(0.5, 4.0) = 1.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

// 采样坐标：只做左右翻转（多帧交给 Sprite3D region / AnimatedSprite3D）
vec2 sample_uv(vec2 local) {
	vec2 l = clamp(local, vec2(0.0), vec2(1.0));
	if (flip_h) {
		l.x = 1.0 - l.x;
	}
	return l;
}

void fragment() {
	vec2 texel = 1.0 / max(sprite_size, vec2(1.0, 1.0));

	vec4 base = texture(albedo_texture, sample_uv(UV));

	// 像素画的硬边裁剪：不透明像素之外一律丢弃，走不透明管线
	if (base.a < alpha_cutoff) {
		discard;
	}

	vec3 col = base.rgb;

	// 状态染色（默认关闭）
	if (tint_amount > 0.0) {
		col = mix(col, tint_color.rgb, tint_amount);
	}

	// 闪白强度曲线：flash_power > 1 时前段掉得快，命中瞬间更"脆"
	float amount = pow(clamp(flash_amount, 0.0, 1.0), flash_power);

	// 边缘提亮：本像素不透明而四邻域透明处即轮廓
	if (rim_boost > 0.0 && amount > 0.0) {
		float a_l = texture(albedo_texture, sample_uv(UV - vec2(texel.x, 0.0))).a;
		float a_r = texture(albedo_texture, sample_uv(UV + vec2(texel.x, 0.0))).a;
		float a_u = texture(albedo_texture, sample_uv(UV - vec2(0.0, texel.y))).a;
		float a_d = texture(albedo_texture, sample_uv(UV + vec2(0.0, texel.y))).a;
		float edge = 1.0 - min(min(a_l, a_r), min(a_u, a_d));
		col += flash_color.rgb * edge * rim_boost * amount;
	}

	// 主体闪白 + 过曝
	col = mix(col, flash_color.rgb, amount);
	col += flash_color.rgb * amount * overexposure;

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
}
