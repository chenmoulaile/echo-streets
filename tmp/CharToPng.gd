extends Node
## 把 tmp/ctex_char 下的 .ctex 批量转成 PNG，输出到 tmp/char_png。

const SRC_DIR := "res://tmp/ctex_char/"
const DST_DIR := "res://tmp/char_png/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST_DIR))
	var files := DirAccess.get_files_at(SRC_DIR)
	var ok := 0
	var bad := 0
	for f in files:
		if not f.ends_with(".ctex"):
			continue
		var src := SRC_DIR + f
		var tex := load(src) as Texture2D
		if tex == null:
			bad += 1
			continue
		var img := tex.get_image()
		if img == null:
			bad += 1
			continue
		var out := DST_DIR + f.get_basename() + ".png"
		if img.save_png(out) != OK:
			bad += 1
			continue
		ok += 1
	print("[char] done ok=%d bad=%d" % [ok, bad])
	get_tree().quit()
