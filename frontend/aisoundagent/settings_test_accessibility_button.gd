extends Button


# 节点引用声明
@onready var ip_input: LineEdit = $"../IPInput"
@onready var port_input: LineEdit = $"../PortInput"
@onready var result_label: RichTextLabel = $"../ResultLabel"
var http_request: HTTPRequest

func _ready():
	# 动态创建HTTPRequest节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# 按钮触发的测试函数
func _on_pressed():
	var ip = ip_input.text.strip_edges()
	var port = port_input.text.strip_edges()
	
	# 输入验证
	if ip.is_empty() or port.is_empty():
		result_label.text = "[color=red]错误：IP或端口不能为空[/color]"
		return
	if not port.is_valid_int():
		result_label.text = "[color=red]错误：端口必须是数字[/color]"
		return
	
	# 构建目标URL（支持HTTP/HTTPS自动判断）
	var url = "http://%s:%s" % [ip, port]
	if port == "443":  # 常用HTTPS端口
		url = "https://%s" % ip
	
	# 发送请求（添加超时处理）
	var error = http_request.request(url, [], HTTPClient.METHOD_GET)
	if error != OK:
		result_label.text = "[color=orange]请求创建失败：错误码 %d[/color]" % error

# 请求完成回调
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	match response_code:
		200:
			result_label.text = "[color=green]连接成功！状态码：200 (Successful Response)[/color]"
		301, 302:
			result_label.text = "[color=cyan]重定向 (状态码 %d)，请检查协议[/color]" % response_code
		403, 404:
			result_label.text = "[color=red]访问失败 (状态码 %d)，目标存在但拒绝访问[/color]" % response_code
		_:
			if result == HTTPRequest.RESULT_TIMEOUT:
				result_label.text = "[color=cyan]请求超时（目标无响应）[/color]"
			else:
				result_label.text = "[color=red]连接失败！状态码：%d，错误：%s[/color]" % [response_code, _get_error_name(result)]

# 错误码翻译（增强可读性）
func _get_error_name(error: int) -> String:
	var errors = {
		HTTPRequest.RESULT_CANT_CONNECT: "无法连接",
		HTTPRequest.RESULT_NO_RESPONSE: "无响应",
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "SSL证书错误"
	}
	return errors.get(error, "未知错误")
