extends Node
## 把从 BOOMDoA.pck 抽出的 .ctex（GST2 容器）转回 PNG。
## Godot 的 ResourceLoader 认识 .ctex 扩展名，load() 后 get_image() 即可拿到解码后的 Image。

const SRC_DIR := "res://tmp/ctex/"
const DST_DIR := "res://tmp/fp_png/"


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
			push_warning("load 失败: " + src)
			bad += 1
			continue
		var img := tex.get_image()
		if img == null:
			push_warning("get_image 为空: " + src)
			bad += 1
			continue
		var out := DST_DIR + f.get_basename() + ".png"
		var err := img.save_png(out)
		if err != OK:
			push_warning("save_png 失败 %d: %s" % [err, out])
			bad += 1
			continue
		ok += 1
		print("[ctex] %s -> %dx%d" % [f, img.get_width(), img.get_height()])
	print("[ctex] done ok=%d bad=%d" % [ok, bad])
	get_tree().quit()
