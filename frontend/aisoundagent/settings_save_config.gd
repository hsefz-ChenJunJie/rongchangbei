extends Button

@onready var ip_input: LineEdit = $"../Panel/IPInput"
@onready var port_input: LineEdit = $"../Panel/PortInput"
@onready var tree: Tree = $"../Panel/Tree"
@onready var interval_input: LineEdit = $"../Panel2/IntervalInput"


func _on_pressed() -> void:
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
	config["ip"] = ip_input.text
	config["port"] = port_input.text
	config["interval"] = int(interval_input.text)
	
	var treeroot = tree.get_root()
	for child_of_root in treeroot.get_children():
		var cfg_spc = {}
		
		for i:TreeItem in child_of_root.get_children():
			if i.get_text(0) != "mode":
				var value_of_cfg = i.get_text(1)
				if not value_of_cfg.begins_with("输入"): 
					cfg_spc[i.get_text(0)] = value_of_cfg
		if not cfg_spc.is_empty():
			config[child_of_root.get_text(0)] = cfg_spc
	
	# 3. 保存更新后的配置
	var save_file = FileAccess.open(config_path, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(config))
		save_file = null
		print("配置已保存")
	else:
		push_error("无法打开配置文件写入: " + str(FileAccess.get_open_error()))


func _on_ready() -> void:
	var config_path = "user://config.json"
	var config = {}
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file != null:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			file = null
			
			if parse_result == OK:
				config = json.get_data()
				if config.has("ip") and config.has("port"):
					ip_input.text = config["ip"]
					port_input.text = config['port']
					interval_input.text = str(config["interval"])
			else:
				push_error("JSON 解析错误: " + json.get_error_message())
		else:
			push_error("无法打开配置文件读取: " + str(FileAccess.get_open_error()))
	
