extends Tree


var config = {}

func _ready():
	setdata()
	# 设置Tree属性
	columns = 2
	column_titles_visible = true
	set_column_title(0, "配置项")
	set_column_title(1, "值")
	hide_root = true
	allow_reselect = true
	
	# 创建三个主分支
	var main_branches = ["stt", "llm", "tts"]
	var root = create_item()
	
	for branch in main_branches:
		var main_item = create_item(root)
		main_item.set_text(0, branch)
		main_item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
		
		# 创建5个子分支
		var sub_items = ["mode", "website", "ip", "port", "api_path"]
		for sub in sub_items:
			var child = create_item(main_item)
			child.set_text(0, sub)
			child.set_icon(0, get_theme_icon("FileList", "EditorIcons"))
			
			if sub == "mode":
				# 模式分支添加复选框
				var options = ["Website", "IP_Port"]
				for opt in options:
					var option_item = create_item(child)
					option_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
					option_item.set_text(0, opt)
					option_item.set_checked(0, false)
					option_item.set_editable(0, true)
			else:
				# 其他分支添加文本输入框
				child.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
				if config.has(branch):
					if config[branch].has(sub):
						child.set_text(1, config[branch][sub])
					else:
						child.set_text(1, "输入" + sub)
				else:
					child.set_text(1, "输入" + sub)
				child.set_editable(1, true)
				if sub != "api_path":
					child.visible = false

# 可选：处理复选框变化事件
func _on_item_edited():
	var edited_item = get_edited()
	if edited_item and edited_item.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK:
		var column = get_edited_column()
		if column == 0:
			var type = edited_item.get_text(0)
			if type == "IP_Port":
				var children_list = edited_item.get_parent().get_parent().get_children()
				for chn_obj in children_list:
					print(chn_obj.get_text(0))
					if chn_obj.get_text(0) == "ip" or chn_obj.get_text(0) == "port":
						chn_obj.visible = edited_item.is_checked(0)
			
			if type == "Website":
				var children_list = edited_item.get_parent().get_parent().get_children()
				for chn_obj in children_list:
					print(chn_obj.get_text(0))
					if chn_obj.get_text(0) == "website":
						chn_obj.visible = edited_item.is_checked(0)

func setdata():
	var config_path = "user://config.json"
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
