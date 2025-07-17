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
	SceneManager.push_scene("res://settings.tscn")

# 保存图片路径到配置文件
func _save_image_path(path):
	var config = {
		"bg": path
	}
	
	# Godot 4 使用 FileAccess 替代 File
	var file = FileAccess.open("user://config.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(config))
		file = null  # 在 Godot 4 中不需要显式 close，但可以置 null
	else:
		push_error("Failed to open config file for writing: " + str(FileAccess.get_open_error()))

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
