## 标题屏 + 设置面板截帧：headless 抓不到画面，必须带窗口跑。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/title_shot_runner.tscn
## 为什么要单独一个 runner：main_scene 现在是 title.tscn，直接跑 --quit-after 只能验证
## 不报错，验证不了排版有没有压字、按钮有没有叠在一起。
extends Node

const SHOT_DIR := "res://tmp/shots/title/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var title: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(title)
	await get_tree().create_timer(0.8).timeout
	_shot("00_title")

	# 设置面板：验证滑条 / 方案按钮在 480x270 逻辑屏里没有溢出
	var panel: Node = title.get_node_or_null(^"SettingsPanel")
	if panel != null:
		panel.call(&"open")
		await get_tree().create_timer(0.5).timeout
		_shot("01_settings")
		panel.call(&"close")
		await get_tree().create_timer(0.3).timeout

	print("[title_shot] done")
	get_tree().quit()

func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = SHOT_DIR + tag + ".png"
	var err: int = img.save_png(path)
	if err == OK:
		print("[title_shot] %s  %dx%d" % [path, img.get_width(), img.get_height()])
	else:
		push_error("保存 %s 失败 err=%d" % [path, err])
