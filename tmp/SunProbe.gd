## 太阳方向光接入验证探针（一次性诊断，不进游戏）
## 为什么需要它：ch04 加完 SUN_DIR 后，截帧左右地面 mean 差仍是 0.000 ——
##   地面法线恒为 UP，方向光对水平面处处等值，所以「地面左右相同」不能证明
##   方向光失效，也不能证明它生效。必须直接读 LightBaker 的静态字段 + 对比
##   同一垂直面在 sun_gain=0 与 0.55 下的烘焙值。
extends SceneTree

func _initialize() -> void:
	var LB := load("res://scripts/level/light_baker.gd")
	var Ch4 := load("res://scripts/level/chapter_04_rooftop.gd")
	var data = Ch4.build()
	print("[sun] chapter sun_gain = %.3f (期望 0.550)" % float(data.sun_gain))
	print("[sun] LightBaker.sun_gain 默认 = %.3f (期望 0.000)" % float(LB.sun_gain))

	# 朝 -X 的墙（法线 (-1,0,0)）：SUN_DIR.x=-0.50 → N·L = +0.50，应该更亮
	# 朝 +X 的墙（法线 (+1,0,0)）：N·L = -0.50 → clamp 到 0，只剩环境光
	var lamps: Array = data.lamps
	var amb_sky: Color = data.ambient_sky
	var amb_g: Color = data.ambient_ground
	for g in [0.0, 0.55]:
		LB.sun_gain = g
		var nx: Color = LB.sample(Vector3(0.0, 1.5, 0.0), Vector3(-1.0, 0.0, 0.0),
			lamps, amb_sky, amb_g, 0.0, {})
		var px: Color = LB.sample(Vector3(0.0, 1.5, 0.0), Vector3(1.0, 0.0, 0.0),
			lamps, amb_sky, amb_g, 0.0, {})
		var up: Color = LB.sample(Vector3(0.0, 0.02, 0.0), Vector3.UP,
			lamps, amb_sky, amb_g, 0.0, {})
		print("[sun] g=%.2f  wall-X r=%.3f  wall+X r=%.3f  差=%.3f   ground r=%.3f" % [
			g, nx.r, px.r, nx.r - px.r, up.r])
	# 复位：static var 会污染后续同进程构建
	LB.sun_gain = 0.0
	print("[sun] done")
	quit()
