extends TextEdit

# 将你的LineEdit和TextEdit节点拖拽到Inspector中的对应变量上
@onready var scene_input: LineEdit = $"../../Panel/SceneInput"
@onready var brief_input: LineEdit = $"../BriefInput"
@onready var context_edit: TextEdit = $"../../Panel/ContextEdit"
@onready var http_request: HTTPRequest = $"../../HTTPRequest"
@onready var suggestions_container: VBoxContainer = $"../SuggestionsContainer"

# API的URL
var api_config = {
	"mode":"ip_port",
	"ip": "127.0.0.1",
	"port": 8000,
	"api_path": "/api/generate_suggestions",
	"suggestion_num": 4
}

func _ready():
	# 连接请求完成的信号
	load_api_config()
	http_request.request_completed.connect(_on_request_completed)
	#generate_suggestions()

func load_api_config():
	var config_path = "user://config.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			var config = json.get_data()
			api_config["ip"] = config["ip"]
			api_config["port"] = config["port"]
			if config.has("llm"):
				api_config["api_path"] = config["llm"]["api_path"]
				if config["llm"].has("website") and config["llm"]["website"]!="":
					api_config["website"] = config["llm"]["website"]
					api_config["mode"] = "web"
				elif config["llm"].has("ip") and config["llm"].has("port"):
					api_config["ip"] = config["llm"]["ip"]
					api_config["port"] = config["llm"]["port"]
			print("Loaded API config: ", api_config)
		else:
			push_error("Failed to parse config.json: " + json.get_error_message())
	else:
		push_error("Failed to open config.json")

# 调用此函数以发送请求
func generate_suggestions():
	# 1. 准备请求头
	var headers = ["Content-Type: application/json"]

	# 2. 准备请求体 (Body)
	var body_dict = {
		"scenario_context": scene_input.text,
		"user_opinion": brief_input.text,
		"target_dialogue": context_edit.text,
		"modification_suggestion": [
				"give me a better version"
			],
		"suggestion_count": api_config["suggestion_num"]
	}
	# 将字典转换为JSON字符串
	var body_json_string = JSON.stringify(body_dict)
	
	var api_url
	if api_config["mode"] == "ip_port":
		api_url = "http://%s:%s%s" % [api_config.ip, str(api_config.port), api_config.api_path]
	else:
		api_url = api_config["website"] + api_config["api_path"]	
	

	# 3. 发送POST请求
	# request()会返回一个错误码，如果是OK则表示请求已成功发出
	var error = http_request.request(api_url, headers, HTTPClient.METHOD_POST, body_json_string)
	if error != OK:
		print("An error occurred in the HTTP request.")


# 当HTTP请求完成时，此函数会被自动调用
func _on_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Request failed!")
		return

	print("Response Code: ", response_code)

	if response_code == 200:
		# 将返回的body（原始字节数据）解析为字符串
		var response_body_string = body.get_string_from_utf8()
		
		# --- 修改开始 ---
		# 按行分割响应体
		var lines = response_body_string.split("\n")
		var json_string = ""
		
		# 遍历每一行，寻找 "data:" 开头的行
		for line in lines:
			if line.begins_with("data:"):
				# 提取 "data:" 后面的部分，并去除可能存在的前后空格
				json_string = line.substr(5).strip_edges()
				break # 假设我们只需要第一个data事件

		if json_string.is_empty():
			print("No 'data:' field found in the SSE response.")
			print("Response Body: ", response_body_string)
			return
		# --- 修改结束 ---

		# 解析提取出来的JSON字符串
		var json = JSON.parse_string(json_string)

		if json:
			# 假设返回的JSON直接就是一个字符串数组
			# 例如: ["suggestion1", "suggestion2", "suggestion3"]
			if json.has("suggestions"):
				var suggestions_array = json["suggestions"]
				print("Suggestions: ", suggestions_array)
				var suggestion_list: Array[String] = []
				for i in suggestions_array:
					# 确保suggestions_array中的元素的"content"键存在
					if i.has("content"):
						suggestion_list.append(str(i["content"]))
				
				# 【重要】调用函数以创建按钮
				_create_suggestion_buttons(suggestion_list)
				
			else:
				print("JSON response does not contain 'suggestions' key.")
				print("Parsed JSON: ", json)
		else:
			print("Failed to parse JSON response.")
			print("Extracted JSON String: ", json_string)
			print("Original Response Body: ", response_body_string)
	else:
		print("Request failed with response code: ", response_code)
		print("Response Body: ", body.get_string_from_utf8())


# 【新增】根据字符串数组在VBoxContainer中创建按钮
func _create_suggestion_buttons(suggestions: Array[String]):
	# 1. 清空容器中之前的所有按钮，以防重复生成
	for child in suggestions_container.get_children():
		child.queue_free() # 安全地删除节点

	# 2. 遍历建议数组，为每一条建议创建一个按钮
	for suggestion_text in suggestions:
		# 确保建议是字符串类型
		if typeof(suggestion_text) == TYPE_STRING:
			var new_button = Button.new()
			new_button.text = suggestion_text
			new_button.add_theme_font_size_override("font_size",36)
			
			# (可选) 你可以在这里设置按钮的其他属性
			# new_button.custom_minimum_size.y = 40 # 例如，设置最小高度
			
			# (可选) 将按钮的 "pressed" 信号连接到一个处理函数
			# 使用 .bind() 可以将按钮的文本直接传递给处理函数
			new_button.pressed.connect(_on_suggestion_button_pressed.bind(suggestion_text))
			
			# 将新创建的按钮添加到VBoxContainer中
			suggestions_container.add_child(new_button)


# 【可选】当任何一个建议按钮被点击时，此函数会被调用
func _on_suggestion_button_pressed(button_text: String):
	print("Suggestion button pressed with text: ", button_text)
	brief_input.text = button_text

func _on_timer_timeout() -> void:
	generate_suggestions()
