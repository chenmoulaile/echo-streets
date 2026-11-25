## 光照数值取证：在真实章节的灯位下，采样若干代表点的烘焙亮度。
## 目的：把「削顶成纯白」从"看着不对"变成"数值超出多少"。
## 判据（照片级要求贴图细节可见）:
##   地板受光区 0.72~0.98、地板灯间 0.55~0.75
##   墙面 0.50~0.80、天花 0.45~0.72
##   任一点 > 1.0 即为削顶（贴图细节被烧掉）
extends Node

const K := preload("res://scripts/level/chapter_kit.gd")
const LB := preload("res://scripts/level/light_baker.gd")

func _ready() -> void:
	var data: RefCounted = load("res://scripts/level/chapter_01_lobby.gd").call("build")
	var lamps: Array = data.get("lamps")
	var sky: Color = data.get("ambient_sky")
	var ground: Color = data.get("ambient_ground")
	print("[light] lamps=%d  amb_sky=%s  amb_ground=%s" % [
		lamps.size(), str(sky), str(ground)])

	# 灯位：x=±3, z 从 -19 步进 6.5（见 chapter_01_lobby._ceiling）
	_probe("地板·灯正下方", Vector3(-3.0, 0.0, -19.0), Vector3.UP, lamps, sky, ground)
	_probe("地板·两灯之间", Vector3(-3.0, 0.0, -15.75), Vector3.UP, lamps, sky, ground)
	_probe("地板·中轴远离灯", Vector3(0.0, 0.0, 0.0), Vector3.UP, lamps, sky, ground)
	_probe("地板·右墙脚", Vector3(10.0, 0.0, 0.0), Vector3.UP, lamps, sky, ground)
	_probe("右墙·齐灯高", Vector3(10.9, 3.2, -19.0), Vector3.LEFT, lamps, sky, ground)
	_probe("右墙·腰部", Vector3(10.9, 1.4, -19.0), Vector3.LEFT, lamps, sky, ground)
	_probe("右墙·灯间", Vector3(10.9, 1.4, -15.75), Vector3.LEFT, lamps, sky, ground)
	_probe("前墙·居中", Vector3(0.0, 1.6, -22.9), Vector3.BACK, lamps, sky, ground)
	_probe("柱面·朝走廊", Vector3(5.85, 1.6, -18.0), Vector3.LEFT, lamps, sky, ground)
	_probe("天花·灯正下方", Vector3(-3.0, 3.6, -19.0), Vector3.DOWN, lamps, sky, ground)
	_probe("天花·中轴", Vector3(0.0, 3.6, 0.0), Vector3.DOWN, lamps, sky, ground)
	get_tree().quit()

func _probe(tag: String, p: Vector3, n: Vector3, lamps: Array,
		sky: Color, ground: Color) -> void:
	var c: Color = LB.sample(p, n, lamps, sky, ground)
	var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var flag: String = "  <== 削顶" if (c.r > 1.0 or c.g > 1.0 or c.b > 1.0) else ""
	print("[light] %-14s rgb(%.3f,%.3f,%.3f) lum=%.3f%s" % [
		tag, c.r, c.g, c.b, lum, flag])
