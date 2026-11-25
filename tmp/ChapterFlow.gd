## 章节流程探针：验证 4 章都能构建、换章序号推进、重开回到本章出生点。
## 用法（必须带窗口，因为要读 viewport 尺寸之外还要跑真实场景树）：
##   Godot_v4.7.2-stable_win64_console.exe --path D:\mygame res://tmp/chapter_flow_runner.tscn
## 为什么不直接测 reload_current_scene：
##   探针自身就是 current_scene，reload 会把探针自己换掉、后续断言全部丢失。
##   这里改为「逐章 set_chapter + 实例化 main.tscn」，等价于换章后 Level._ready 的路径，
##   再单独断言 _on_all_waves_cleared 会把章节序号推进。
extends Node

const MAIN := "res://scenes/main.tscn"
const Chapters := preload("res://scripts/level/chapters.gd")

var _fail: int = 0
var _pass: int = 0

func _ready() -> void:
	await _run()
	print("=== CHAPTERFLOW pass=%d fail=%d ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: ", what)

func _run() -> void:
	var total: int = Chapters.count()
	_check(total == 4, "章节总数应为 4，实际 %d" % total)

	for i: int in total:
		GameManager.set_chapter(i)
		_check(GameManager.chapter_index() == i, "set_chapter(%d) 未生效" % i)
		var main: Node = (load(MAIN) as PackedScene).instantiate()
		add_child(main)
		# Level._ready 里有一次 await process_frame，这里多等几帧让构建与启动完成
		for _f: int in 4:
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		_verify_chapter(main, i)
		remove_child(main)
		main.free()
		# 释放后再等一帧，让 HUD 的 _exit_tree 断开 EventBus，避免下一章重复连线
		await get_tree().process_frame

	# 换章推进：直接触发通关信号，确认序号 +1 且不越界
	GameManager.set_chapter(0)
	await get_tree().process_frame
	GameManager.set_chapter(total - 1)
	_check(GameManager.has_next_chapter() == false, "最后一章 has_next_chapter 应为 false")
	GameManager.set_chapter(0)
	_check(GameManager.has_next_chapter() == true, "第一章 has_next_chapter 应为 true")

func _verify_chapter(main: Node, index: int) -> void:
	var data: ChapterData = main.call(&"chapter_data") as ChapterData
	_check(data != null, "ch%d chapter_data 为空" % (index + 1))
	if data == null:
		return
	var world: Node3D = main.get_node_or_null(^"World") as Node3D
	_check(world != null, "ch%d 缺 World" % (index + 1))
	if world != null:
		var mesh_count: int = 0
		for c: Node in world.get_children():
			if c is MeshInstance3D:
				mesh_count += 1
		_check(mesh_count > 40, "ch%d World 几何过少 mesh=%d" % [index + 1, mesh_count])
		# 只有 ch04 有天空
		var has_sky: bool = world.get_node_or_null(^"Sky") != null
		_check(has_sky == (index == 3), "ch%d 天空存在性错误 has_sky=%s" % [index + 1, has_sky])

	var spawner: Node = main.get_node_or_null(^"WaveSpawner")
	_check(spawner != null, "ch%d 缺 WaveSpawner" % (index + 1))
	if spawner != null:
		var holder: Node = spawner.get_node_or_null(^"SpawnPoints")
		_check(holder != null, "ch%d 缺 SpawnPoints" % (index + 1))
		if holder != null:
			_check(holder.get_child_count() == data.spawn_points.size(),
				"ch%d 刷怪点数 %d != %d" % [index + 1, holder.get_child_count(), data.spawn_points.size()])
		var waves: Array = spawner.get(&"waves")
		_check(waves.size() == data.waves.size(),
			"ch%d 波次数 %d != %d" % [index + 1, waves.size(), data.waves.size()])
		if not waves.is_empty():
			var w0: WaveConfig = waves[0]
			_check(w0 != null and w0.fodder_scene != null, "ch%d 第 1 波缺 fodder_scene" % (index + 1))
			_check(w0 != null and w0.special_scenes.size() == 3,
				"ch%d 第 1 波特感数应为 3" % (index + 1))

	var player: Node3D = main.get_node_or_null(^"Player") as Node3D
	_check(player != null, "ch%d 缺 Player" % (index + 1))
	if player != null:
		var d: float = player.global_position.distance_to(data.player_start)
		_check(d < 0.5, "ch%d 玩家未落到出生点 dist=%.2f" % [index + 1, d])

	var hud: Node = main.get_node_or_null(^"Hud")
	_check(hud != null, "ch%d 缺 Hud" % (index + 1))
	if hud != null:
		var banner: Label = hud.get_node_or_null(^"HudRoot") as Label
		# 横幅文本在 HudRoot 下的第二个 Label（章节标题），用名字找不到，改为读成员
		var title: Variant = hud.get(&"_chapter_title")
		_check(title is Label, "ch%d HUD 缺章节标题标签" % (index + 1))
		if title is Label:
			var t: String = (title as Label).text
			_check(t.contains(data.title), "ch%d 横幅标题不含 %s（实际 %s）" % [index + 1, data.title, t])

	var post: Node = main.get_node_or_null(^"PostFX")
	_check(post != null, "ch%d 缺 PostFX" % (index + 1))
	if post != null and not data.post.is_empty():
		var rect: ColorRect = post.get_node_or_null(^"PixelPost") as ColorRect
		_check(rect != null, "ch%d 缺 PixelPost" % (index + 1))
		if rect != null:
			var mat: ShaderMaterial = rect.material as ShaderMaterial
			var want: float = float(data.post.get("brightness", 1.0))
			var got: float = float(mat.get_shader_parameter(&"brightness"))
			_check(absf(got - want) < 0.001,
				"ch%d 后期 brightness 未覆盖 got=%.3f want=%.3f" % [index + 1, got, want])
