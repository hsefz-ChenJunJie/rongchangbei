extends Button

# 信号：通知背景已更改
signal background_changed(image_path)

# 节点引用
var file_dialog: FileDialog

func _ready():
	# 创建文件对话框
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG 图片", "*.jpg ; JPG 图片"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	# 如果是安卓，请求权限
	if OS.get_name() == "Android" and not Engine.is_editor_hint():
		_request_android_permissions()

# 打开图片选择器
func open_image_picker():
	file_dialog.popup_centered_ratio(0.8)

# 处理选择的文件
func _on_file_selected(path):
	# 将路径保存到配置文件中
	_save_image_path(path)
	# 发出信号通知背景已更改
	background_changed.emit(path)
	get_tree().change_scene_to_file("res://settings.tscn")

# 保存图片路径到配置文件
func _save_image_path(path):
	var config_path = "user://config.json"
	var config = {}
	
	# 1. 尝试读取现有配置
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file != null:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			file = null
			
			if parse_result == OK:
				config = json.get_data()
			else:
				push_error("JSON 解析错误: " + json.get_error_message())
		else:
			push_error("无法打开配置文件读取: " + str(FileAccess.get_open_error()))
	
	# 2. 更新背景路径
	config["bg"] = path
	
	# 3. 保存更新后的配置
	var save_file = FileAccess.open(config_path, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(config))
		save_file = null
		print("配置已保存")
	else:
		push_error("无法打开配置文件写入: " + str(FileAccess.get_open_error()))

# 请求安卓权限
func _request_android_permissions():
	# 确保是 Android 平台且不在编辑器中
	if OS.get_name() == "Android" and not Engine.is_editor_hint():
		# 在 Godot 4 中，使用新的权限请求方式
		if OS.has_feature("editor"):
			print("在编辑器中，跳过权限请求")
			return
			
		# 请求存储权限
		if not OS.request_permission("android.permission.READ_EXTERNAL_STORAGE"):
			push_error("Failed to request storage permission")

func _on_pressed() -> void:
	open_image_picker()
