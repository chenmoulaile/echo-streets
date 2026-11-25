## 光照参数扫描：在真实灯位下遍历 (energy, range, ambient) 组合，
## 用判据打分选出「有光斑层次且不削顶」的一组，而不是凭手感反复微调。
## 判据（照片级要求）:
##   floor_lit  0.80~0.97   地板灯正下方（要亮但留细节）
##   floor_mid  0.55~0.78   地板两灯之间（明显更暗 → 光斑层次）
##   wall       0.45~0.80   墙面腰部
##   ceil       0.40~0.72   天花板灯正下方
##   contrast = floor_lit - floor_mid >= 0.15（小于这个值画面就是平的）
extends Node

const K := preload("res://scripts/level/chapter_kit.gd")
const LB := preload("res://scripts/level/light_baker.gd")

func _ready() -> void:
	# 真实灯位（chapter_01_lobby._ceiling）：x=±3，z 从 -19 步进 6.5，灯高 3.4
	var base_lamps: Array = []
	var z: float = -19.0
	while z <= 19.0:
		for sx: float in [-1.0, 1.0]:
			base_lamps.append([Vector3(sx * 3.0, 3.4, z), Color(1.0, 0.97, 0.90)])
		z += 6.5

	var best: Array = []
	for energy: float in [2.0, 2.6, 3.2, 4.0]:
		for rng: float in [5.0, 6.0, 7.0, 8.0]:
			for amb: float in [0.34, 0.40, 0.46]:
				var lamps: Array = []
				for it: Array in base_lamps:
					lamps.append(K.lamp(it[0], it[1], energy, rng))
				var sky := Color(amb, amb * 1.02, amb * 1.08)
				var gr := Color(amb * 0.5, amb * 0.49, amb * 0.48)
				var lit: float = _lum(Vector3(-3.0, 0.0, -19.0), Vector3.UP, lamps, sky, gr)
				var mid: float = _lum(Vector3(-3.0, 0.0, -15.75), Vector3.UP, lamps, sky, gr)
				var wall: float = _lum(Vector3(10.9, 1.4, -19.0), Vector3.LEFT, lamps, sky, gr)
				var ceil_: float = _lum(Vector3(-3.0, 3.6, -19.0), Vector3.DOWN, lamps, sky, gr)
				var contrast: float = lit - mid
				var score: int = 0
				if lit >= 0.80 and lit <= 0.97: score += 3
				if mid >= 0.55 and mid <= 0.78: score += 3
				if wall >= 0.45 and wall <= 0.80: score += 2
				if ceil_ >= 0.40 and ceil_ <= 0.72: score += 2
				if contrast >= 0.15: score += 4
				if contrast >= 0.25: score += 2
				best.append({"s": score, "e": energy, "r": rng, "a": amb,
					"lit": lit, "mid": mid, "wall": wall, "ceil": ceil_,
					"c": contrast})

	best.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x["s"]) > int(y["s"]))
	print("[scan] 前 8 名（满分 16）:")
	for i: int in mini(8, best.size()):
		var b: Dictionary = best[i]
		print("  #%d score=%d/16  energy=%.1f range=%.1f amb=%.2f  "
			% [i + 1, b["s"], b["e"], b["r"], b["a"]]
			+ "lit=%.3f mid=%.3f wall=%.3f ceil=%.3f contrast=%.3f"
			% [b["lit"], b["mid"], b["wall"], b["ceil"], b["c"]])
	get_tree().quit()

func _lum(p: Vector3, n: Vector3, lamps: Array, sky: Color, gr: Color) -> float:
	var c: Color = LB.sample(p, n, lamps, sky, gr)
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
