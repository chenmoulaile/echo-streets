## HUD 专项截帧：命中标记（普通 / 弱点）、换弹环、低血状态。
## 直接实例化 main.tscn，然后用 EventBus 打信号驱动 HUD —— 不依赖真实战斗，
## 因为命中标记只活 0.22 秒，靠实战截帧抓不准时机。
extends Node

const OUT := "res://tmp/shots/hud/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout

	await _shot("01_idle")

	# 普通命中：连打三发，验证重复命中会重置进度而不是叠加
	EventBus.zombie_hit.emit(null, 10.0, false)
	await get_tree().create_timer(0.05).timeout
	await _shot("02_hit_body")

	# 弱点命中：金色 + 圆环
	await get_tree().create_timer(0.30).timeout
	EventBus.zombie_hit.emit(null, 20.0, true)
	await get_tree().create_timer(0.05).timeout
	await _shot("03_hit_weak")

	# 命中淡出中段：验证弹开与淡出是两条独立曲线
	await get_tree().create_timer(0.10).timeout
	EventBus.zombie_hit.emit(null, 10.0, false)
	await get_tree().create_timer(0.09).timeout
	await _shot("04_hit_mid")

	# 换弹环：发 reload_started，等 0.6 秒抓中段进度
	await get_tree().create_timer(0.30).timeout
	EventBus.reload_started.emit(1.35)
	await get_tree().create_timer(0.60).timeout
	await _shot("05_reload_ring")
	EventBus.reload_finished.emit()

	# 低血：危险色 + 呼吸
	await get_tree().create_timer(0.30).timeout
	EventBus.player_health_changed.emit(22.0, 100.0)
	await get_tree().create_timer(0.20).timeout
	await _shot("06_low_hp")

	# 空仓：弹药变红
	EventBus.ammo_changed.emit(0, 48)
	await get_tree().create_timer(0.10).timeout
	await _shot("07_empty")

	print("[hud] done")
	get_tree().quit()

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OUT + name_ + ".png"
	var err: int = img.save_png(path)
	print("[hud] %s %dx%d err=%d" % [path, img.get_width(), img.get_height(), err])
