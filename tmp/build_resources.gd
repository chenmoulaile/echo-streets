## 生成 data/*.tres（WeaponData）。用 Godot 自己写资源文件，避免手写 .tres 格式出错。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame --headless --script res://tmp/build_resources.gd
extends SceneTree

const DATA_DIR := "res://data/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	_pistol()
	_shotgun()
	print("[build_resources] done")
	quit()

func _pistol() -> void:
	var d := WeaponData.new()
	d.display_name = "PISTOL"
	d.weapon_class = WeaponData.WeaponClass.KINETIC
	d.hud_texture = load("res://assets/sprites/weapon_pistol_hud.png")
	d.fire_mode = WeaponData.FireMode.SEMI_AUTO
	d.rounds_per_minute = 340.0
	d.pellets = 1
	d.spread_degrees = 0.9
	d.damage = 22.0
	d.weakspot_multiplier = 2.0
	d.max_range = 90.0
	d.recoil = 1.2
	d.burst_count = 3
	d.magazine_size = 12
	d.reserve_ammo = 60
	d.max_reserve_ammo = 180
	d.reload_time = 1.35
	d.reload_per_shell = false
	_save(d, "weapon_pistol.tres")

func _shotgun() -> void:
	var d := WeaponData.new()
	d.display_name = "SHOTGUN"
	d.weapon_class = WeaponData.WeaponClass.KINETIC
	d.hud_texture = load("res://assets/sprites/weapon_shotgun_hud.png")
	d.fire_mode = WeaponData.FireMode.SEMI_AUTO
	d.rounds_per_minute = 92.0
	d.pellets = 8
	d.spread_degrees = 6.5
	d.damage = 11.0
	d.weakspot_multiplier = 1.5
	d.max_range = 40.0
	d.recoil = 3.6
	d.burst_count = 3
	d.magazine_size = 6
	d.reserve_ammo = 24
	d.max_reserve_ammo = 48
	d.reload_time = 2.4
	d.reload_per_shell = true
	_save(d, "weapon_shotgun.tres")

func _save(d: WeaponData, file_name: String) -> void:
	var issues := d.validate()
	if not issues.is_empty():
		push_error("WeaponData %s 非法: %s" % [file_name, str(issues)])
	var path := DATA_DIR + file_name
	var err := ResourceSaver.save(d, path)
	if err != OK:
		push_error("保存失败 %s err=%d" % [path, err])
	else:
		print("[build_resources] wrote ", path)
