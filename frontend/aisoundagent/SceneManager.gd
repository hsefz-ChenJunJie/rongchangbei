extends Node
var scene_stack = []  # 场景栈

# 在项目启动脚本中（如autoload脚本）
func _ready():
	# 设置默认字体
	var font = preload("res://YanShiChunFengKai-2.ttf")
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 16

func push_scene(path: String):
	scene_stack.append(get_tree().current_scene.scene_file_path)
	get_tree().change_scene_to_file(path)

func pop_scene():
	if scene_stack.size() > 0:
		var prev_path = scene_stack.pop_back()
		get_tree().change_scene_to_file(prev_path)
