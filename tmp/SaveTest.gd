extends Node
func _ready() -> void:
	var big := Image.create(2048, 1024, false, Image.FORMAT_RGB8)
	big.fill(Color(0.4, 0.3, 0.2))
	print("[t] big fill ok")
	var e1: int = big.save_png(ProjectSettings.globalize_path("res://assets/textures/_big1.png"))
	print("[t] big1 -> %d" % e1)
	var e2: int = big.save_png(ProjectSettings.globalize_path("res://assets/textures/sky_rooftop_equirect.png"))
	print("[t] big2 -> %d" % e2)
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/materials/SkyTexture_Sunset.png"))
	print("[t] src loaded %s" % (str(src.get_size()) if src != null else "null"))
	var e3: int = big.save_png(ProjectSettings.globalize_path("res://assets/textures/_big3.png"))
	print("[t] big3 after load -> %d" % e3)
	get_tree().quit()
