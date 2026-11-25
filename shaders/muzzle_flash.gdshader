// =============================================================================
// muzzle_flash.gdshader
// =============================================================================
// shader_type : canvas_item
//
// 适用节点
//   - 枪口火光。三种挂法，按 PDF「枪械 HUD 为 2D 像素帧动画叠加于 Control 层」：
//     A) HUD 层（最贴合 PDF 方案）：ColorRect，铺在枪口位置，尺寸约 96~160 见方。
//        实测要点：TextureRect 若没赋 texture 则整节点不绘制，着色器完全不生效；
//        要用 TextureRect 必须先塞一张占位贴图。ColorRect 无此问题，优先用 ColorRect。
//        脚本在开火后把 lifetime 0 -> 1 推进约 0.05 秒。
//     B) 世界内：挂在枪口处的 Sprite3D（billboard）+ material_override 走 canvas_item。
//        注意 Sprite3D 需给 texture（占位像素图），否则同样不绘制。
//     C) 粒子：作为 GPUParticles2D/3D 的 draw pass 材质，UV 由粒子四边形提供。
//   - 材质需 blend_add（本文件已在 render_mode 声明），不要额外开启 "Use Alpha"。
//
// 功能
//   1. 纯程序化枪口火光：核心圆盘 + 花瓣状外焰 + 水平长条火花，不依赖贴图即可用
//   2. 每发随机形态：random_seed 决定旋转角、花瓣长度、火花拉伸
//   3. 生命周期衰减：lifetime 0(刚击发)->1(熄灭)，整体收缩 + 淡出
//   4. HDR 亮度增益：emission_boost 让火光超过 1.0，供 WorldEnvironment 泛光提取
//   5. 可选叠加外部像素贴图（flash_texture），与程序化形状相乘
//
// 兼容性
//   Godot 4.x / Compatibility(gl_compatibility) 渲染器可用；无循环、无分支密集逻辑，
//   移动端开销可忽略。
//
// uniform 说明与推荐值
//   lifetime        生命周期 0~1，脚本驱动。推荐开火后 0.05 秒内走完。
//   random_seed     每发随机种子 0~1，脚本写 randf()。推荐每发必换。
//   core_color      核心色（source_color）。推荐 vec4(1.0, 0.97, 0.82, 1.0) 近白暖黄。
//   flame_color     外焰色（source_color）。推荐 vec4(1.0, 0.45, 0.10, 1.0) 橙红。
//   size            整体尺寸 0.5~2.0。推荐 1.0（霰弹枪可 1.6，手枪 0.8）。
//   petal_count     花瓣数 4~12。推荐 6。
//   stretch         水平火花拉伸 0.5~4。推荐 1.8（枪口横向喷溅感）。
//   emission_boost  亮度增益 1~6。推荐 2.5（有泛光）/ 1.2（无泛光的 Compatibility）。
//   flash_texture   可选像素火光贴图（filter_nearest）。不绑定 = 默认白，纯程序化。
// =============================================================================
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float lifetime : hint_range(0.0, 1.0) = 0.0;
uniform float random_seed : hint_range(0.0, 1.0) = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.45, 0.10, 1.0);
uniform float size : hint_range(0.5, 2.0) = 1.0;
uniform float petal_count : hint_range(4.0, 12.0) = 6.0;
uniform float stretch : hint_range(0.5, 4.0) = 1.8;
uniform float emission_boost : hint_range(1.0, 6.0) = 2.5;
uniform sampler2D flash_texture : filter_nearest, hint_default_white;

// 确定性伪随机：同一 seed 每帧结果一致，避免火光闪烁抖动
float hash11(float n) {
	return fract(sin(n * 127.1 + random_seed * 311.7) * 43758.5453);
}

void fragment() {
	float t = clamp(lifetime, 0.0, 1.0);
	float decay = 1.0 - t;

	// 以 UV 中心为原点，按 seed 旋转，再按 stretch 横向拉长
	vec2 p = (UV - 0.5) * 2.0 / max(size, 0.001);
	float ang0 = hash11(1.0) * 6.2831853;
	float cs = cos(ang0);
	float sn = sin(ang0);
	p = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
	p.x /= max(stretch, 0.001);

	float r = length(p);
	float ang = atan(p.y, p.x);

	// 花瓣状外焰：正弦调制半径，phase 让每发形状不同
	float phase = hash11(2.0) * 6.2831853;
	float petals = abs(cos(ang * petal_count * 0.5 + phase));
	float petal_len = mix(0.40, 1.0, petals) * (0.72 + 0.45 * hash11(3.0));

	// 生命周期：整体收缩 + 淡出
	float shape = petal_len * mix(0.55, 1.0, decay);
	float core = smoothstep(0.30 * decay, 0.0, r);
	float flame = smoothstep(shape, shape * 0.30, r) * decay;

	// 中心水平火花条：细长高亮，强化"喷"的方向性
	float streak = smoothstep(0.055, 0.0, abs(p.y)) * smoothstep(1.15, 0.0, abs(p.x)) * decay;

	// 可选外部像素贴图调制（默认白贴图，不改变形状）
	float tex_mod = texture(flash_texture, UV).r;
	flame *= tex_mod;
	streak *= tex_mod;

	vec3 col = core_color.rgb * core
		+ flame_color.rgb * flame * (1.0 - core * 0.55)
		+ core_color.rgb * streak * 0.85;
	float alpha = clamp(core + flame + streak * 0.6, 0.0, 1.0) * decay;

	// HDR 增益供泛光提取
	COLOR = vec4(col * emission_boost, alpha);
}
