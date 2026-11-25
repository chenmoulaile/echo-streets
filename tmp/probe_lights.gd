## 探针：确认 Compatibility 渲染器的每物体灯光上限键名与默认值，
## 以及当前项目里各渲染相关键的实际生效值。
## 运行：Godot_v4.7.2-stable_win64_console.exe --path D:\mygame --headless res://tmp/probe_lights_runner.tscn
extends Node

const KEYS := [
	"rendering/limits/opengl/max_lights_per_object",
	"rendering/limits/opengl/max_renderable_lights",
	"rendering/limits/opengl/max_renderable_elements",
	"rendering/limits/opengl/max_renderable_reflections",
	"rendering/renderer/rendering_method",
	"rendering/anti_aliasing/quality/msaa_3d",
	"rendering/environment/defaults/default_environment",
]

func _ready() -> void:
	print("=== RENDERER: ", RenderingServer.get_video_adapter_name())
	print("=== METHOD: ", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	for k: String in KEYS:
		var has: bool = ProjectSettings.has_setting(k)
		var v: Variant = ProjectSettings.get_setting(k, "<missing>")
		print("KEY ", k, " | has=", has, " | value=", v)
	# 灯光上限对单个 MeshInstance3D 的实际影响只能靠渲染验证；
	# 这里先把「同一物体超过上限后多出的灯被忽略」这一假设的来源钉死：
	# 该键存在且默认 8 → 分块建面是必要防御。
	print("=== RESULT max_lights=",
		ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", -1))
	get_tree().quit()
