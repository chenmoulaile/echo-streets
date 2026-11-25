## 探针：Compatibility(OpenGL3) 渲染器是否支持 PanoramaSkyMaterial 真实天空盒。
## 结论决定第四章天台用「贴平面天空板」还是「真 skybox」。
## 必须带窗口跑：--headless 下 viewport 纹理读不到。
extends Node

const OUT := "res://tmp/shots/sky/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 400.0
	cam.rotation = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
	add_child(cam)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/materials/SkyTexture_Sunset.png")
	sky.sky_material = pano
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	# 一块地面，用来确认地平线位置与遮挡关系
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.40)
	mi.material_override = mat
	add_child(mi)

	for pair: Array in [[0.0, "yaw000"], [90.0, "yaw090"], [180.0, "yaw180"], [270.0, "yaw270"]]:
		cam.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(float(pair[0])), 0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var out: String = OUT + "sky_" + String(pair[1]) + ".png"
		print("[sky] %s save=%d size=%dx%d" % [pair[1], img.save_png(out),
			img.get_width(), img.get_height()])

	# 采样画面上半部中心像素：全黑说明天空没渲染
	var probe: Image = get_viewport().get_texture().get_image()
	var top: Color = probe.get_pixel(probe.get_width() / 2, 20)
	var mid: Color = probe.get_pixel(probe.get_width() / 2, probe.get_height() / 2)
	print("[sky] top=%s mid=%s" % [top.to_html(false), mid.to_html(false)])
	get_tree().quit()
