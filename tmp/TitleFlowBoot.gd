## 切场景探针的引导器。
## 为什么不能把验证逻辑直接写在主场景脚本里：
##   `change_scene_to_file()` 释放的是 current_scene —— 也就是主场景根节点本身。
##   逻辑写在那里，切场景瞬间协程随节点一起没了，`get_tree()` 返回 null，
##   报 `Invalid access to property or key 'root' on a base object of type
##   'null instance'` 然后进程挂死（踩过三次）。
## 做法：本脚本只负责把一个 Harness 挂到 root 下（它不是 current_scene，
## 切场景动不了它），之后自己什么也不做，安静等着被换掉。
## 运行：Godot --headless --path D:\mygame res://tmp/title_flow_runner.tscn
extends Node

const HARNESS := preload("res://tmp/TitleFlowHarness.gd")

func _ready() -> void:
	var h: Node = HARNESS.new()
	h.name = "TitleFlowHarness"
	# _ready 期间 root 正在挂子节点，直接 add_child 会报 "Parent node is busy"，
	# 必须延到本帧末尾。
	get_tree().root.add_child.call_deferred(h)
