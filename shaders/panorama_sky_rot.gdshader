// 可旋转的全景天空。
// 存在理由: PanoramaSkyMaterial 没有 rotation 属性，WorldEnvironment 也不是 Node3D
//   （没有 position/rotation），所以"同一张天空图在不同章转到不同方位"这件事
//   只能自己写 sky shader，把旋转做成 uniform。
// 采样约定: 等距柱状（equirectangular）2:1。
//   v = acos(dir.y) / PI  → v=0 是天顶、v=0.5 严格是地平线、v=1 是天底。
//   这就是为什么 assets/textures/sky_rooftop_equirect.png 必须把地平线压到 v=0.5：
//   否则地面 y=0 与天空地平线对不上，天台看起来像悬在半空。
shader_type sky;

uniform sampler2D panorama : source_color, filter_linear_mipmap;
// 绕 Y 轴旋转（度）。正值让画面向右转。
uniform float rotation_deg = 0.0;
// 整体曝光。天空同时被 Environment 当作环境光来源，太亮会把烘焙好的明暗压平。
uniform float exposure = 1.0;
// 地平线以下的压暗系数。0 = 保持原样，1 = 全黑。
// 天台往下看是城市雾霭，需要比原图的地面更暗才不像"站在沙漠里"。
uniform float below_horizon_darken = 0.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float a = radians(rotation_deg);
	float ca = cos(a);
	float sa = sin(a);
	// 绕 Y 轴转方向向量（不是转 UV，转 UV 会在接缝处拉丝）
	vec3 r = vec3(ca * d.x - sa * d.z, d.y, sa * d.x + ca * d.z);

	float u = atan(r.z, r.x) * 0.15915494 + 0.5; // 1/(2*PI)
	float v = acos(clamp(r.y, -1.0, 1.0)) * 0.31830989; // 1/PI
	vec3 c = texture(panorama, vec2(u, v)).rgb;

	// 地平线以下按 v 线性压暗，避免"天空底部一块亮黄"糊住整个下半屏
	if (v > 0.5) {
		float k = (v - 0.5) * 2.0;
		c *= mix(1.0, 1.0 - below_horizon_darken, k);
	}

	COLOR = c * exposure;
}
