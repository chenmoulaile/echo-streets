## 换章实跑探针 —— 启动器。
## 为什么分两个文件：本脚本挂在 advance_runner.tscn 里，是 current_scene 的一部分，
## reload_current_scene() 会连它一起 free。所以它只负责 new 一个 AdvanceProbe
## 挂到 get_tree().root 下（root 不随场景切换释放），然后立刻放手 ——
## 一旦 await 在本节点上等结果，场景被换掉时协程随之销毁，最终打印与 quit 全部丢失。
## 收尾（打印 + quit）由 AdvanceProbe 自己的 _ready → start 负责。
## 为什么先 await 一帧再 add_child：
##   _ready 期间父节点处于 "正在设置子节点" 的忙状态，直接 add_child 报
##   "Parent node is busy setting up children"；而 add_child.call_deferred 在
##   同一批 deferred 调用里执行时 root 仍未脱离该状态，实测同样失败。
##   等一帧之后 root 已空闲，可以同步 add_child。
extends Node

const Probe := preload("res://tmp/AdvanceProbe.gd")

func _ready() -> void:
	_spawn.call_deferred()

func _spawn() -> void:
	await get_tree().process_frame
	var probe: Node = Probe.new()
	probe.name = "AdvanceProbe"
	get_tree().root.add_child(probe)
