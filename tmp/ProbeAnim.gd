extends Node
## 探针：确认 AnimatedSprite3D 的属性面（billboard / sprite_frames / animation），
## 并统计 Droid 各状态的透明包围盒，用于确定统一的裁剪窗口。

const CHAR_DIR := "res://tmp/char_png/"
const DIRS := ["Front", "FrontLeft", "FrontRight", "Left", "Right", "Back", "LeftBack", "RightBack"]
const STATES := ["idle", "run_ing", "fire_ing", "death"]


func _ready() -> void:
	_probe_animated_sprite_3d()
	_probe_bboxes()
	get_tree().quit()


func _probe_animated_sprite_3d() -> void:
	var node := AnimatedSprite3D.new()
	print("[probe] class=", node.get_class())
	var wanted := ["billboard", "sprite_frames", "animation", "frame", "playing", "pixel_size", "shaded", "alpha_cut", "texture_filter", "double_sided", "no_depth_test", "render_priority", "centered", "offset"]
	for w in wanted:
		var has := false
		for p in node.get_property_list():
			if String(p.get("name", "")) == w:
				has = true
				break
		print("[probe] prop %-16s %s" % [w, "YES" if has else "NO"])
	node.free()


func _probe_bboxes() -> void:
	var gmin := Vector2i(99999, 99999)
	var gmax := Vector2i(-1, -1)
	for st in STATES:
		for d in DIRS:
			var files := _frames(st, d)
			if files.is_empty():
				print("[bbox] %s/%s 无帧" % [st, d])
				continue
			var mn := Vector2i(99999, 99999)
			var mx := Vector2i(-1, -1)
			for f in files:
				var img := Image.load_from_file(ProjectSettings.globalize_path(CHAR_DIR + f))
				if img == null:
					continue
				var used := img.get_used_rect()
				mn.x = mini(mn.x, used.position.x)
				mn.y = mini(mn.y, used.position.y)
				mx.x = maxi(mx.x, used.position.x + used.size.x)
				mx.y = maxi(mx.y, used.position.y + used.size.y)
				gmin.x = mini(gmin.x, used.position.x)
				gmin.y = mini(gmin.y, used.position.y)
				gmax.x = maxi(gmax.x, used.position.x + used.size.x)
				gmax.y = maxi(gmax.y, used.position.y + used.size.y)
			print("[bbox] %-8s %-10s n=%2d  (%d,%d)-(%d,%d)  %dx%d" % [st, d, files.size(), mn.x, mn.y, mx.x, mx.y, mx.x - mn.x, mx.y - mn.y])
	print("[bbox] GLOBAL (%d,%d)-(%d,%d) %dx%d" % [gmin.x, gmin.y, gmax.x, gmax.y, gmax.x - gmin.x, gmax.y - gmin.y])


func _frames(state: String, dir: String) -> PackedStringArray:
	var prefix := "Droid__%s__%s__" % [state, dir]
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(CHAR_DIR):
		if f.begins_with(prefix) and f.ends_with(".png"):
			out.append(f)
	var arr := Array(out)
	arr.sort()
	return PackedStringArray(arr)
