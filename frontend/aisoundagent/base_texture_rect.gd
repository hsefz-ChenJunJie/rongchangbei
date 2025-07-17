extends TextureRect

func _ready():
	# 加载背景图片
	load_background()
	
	# 配置显示属性 (Godot 4 属性名变化)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

# 加载背景图片
func load_background():
	var config_path = "user://config.json"
	
	# 检查配置文件是否存在
	if not FileAccess.file_exists(config_path):
		print("配置文件不存在")
		return
	
	# 读取配置文件
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open config file: " + str(FileAccess.get_open_error()))
		return
	
	# 解析 JSON
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file = null  # 关闭文件
	
	if parse_result != OK:
		push_error("JSON 解析错误: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return
	
	# 获取背景路径
	var config = json.get_data()
	var image_path = config.get("bg", "")
	
	if image_path != "":
		_set_background(image_path)

# 设置背景图片 (Godot 4 图片加载方式变化)
func _set_background(path):
	# 检查文件是否存在
	if not FileAccess.file_exists(path):
		push_error("图片文件不存在: " + path)
		return
	
	# 加载图片
	var image = Image.load_from_file(path)
	if image == null:
		push_error("无法加载图片: " + path)
		return
	
	# 创建纹理
	var texture = ImageTexture.create_from_image(image)
	self.texture = texture

# 更新背景图片
func update_background(path):
	_set_background(path)
