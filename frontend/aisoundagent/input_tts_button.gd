extends Button

# ！！！！重要！！！！
# 请根据您在场景中的实际节点路径进行修改
# 1. TextEdit: 用于输入文本
@onready var text_edit: TextEdit = $"../TextEdit"
# 2. TTS_Request: 用于发送文本转语音请求
@onready var tts_request: HTTPRequest = $TTS_Request
# 3. Speakers_Request: 用于获取可用说话人列表 (现在用于检查API状态)
@onready var speakers_request: HTTPRequest = $Speaker_Request
# 4. AudioStreamPlayer: 用于播放合成的音频
@onready var audio_player: AudioStreamPlayer = $"../../Panel/RecordControl/AudioStreamPlayer"
# 5. SpeakerSelector: 用于显示和选择说话人 (现在仅用于显示状态)
@onready var speaker_selector: OptionButton = $OptionButton


# API配置
var api_config = {
	"mode": "ip_port",
	"ip": "127.0.0.1",
	"port": 8000,
	"tts_path": "/api/tts",
	"speakers_path": "/api/tts/speakers",
	"website": ""
}

func _ready():
	# 连接信号
	speakers_request.request_completed.connect(_on_speakers_request_completed)
	tts_request.request_completed.connect(_on_tts_request_completed)
	
	# 加载外部配置并获取API状态
	load_api_config()
	check_api_status()
	

func load_api_config():
	var config_path = "user://config.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	
	if not file:
		print("config.json 未找到, 将使用默认配置。")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error == OK:
		var config = json.get_data()
		# 通用配置
		if config.has("ip"): api_config["ip"] = config["ip"]
		if config.has("port"): api_config["port"] = config["port"]
		
		# TTS特定配置
		if config.has("tts"):
			var tts_config = config["tts"]
			if tts_config.has("website") and tts_config["website"] != "":
				api_config["mode"] = "web"
				api_config["website"] = tts_config["website"]
			elif tts_config.has("ip") and tts_config.has("port"):
				api_config["ip"] = tts_config["ip"]
				api_config["port"] = tts_config["port"]
			
			if tts_config.has("api_path"): api_config["tts_path"] = tts_config["api_path"]
			if tts_config.has("speakers_path"): api_config["speakers_path"] = tts_config["speakers_path"]
			
		print("API 配置已加载: ", api_config)
	else:
		push_error("解析 config.json 失败: " + json.get_error_message())


# [MODIFIED] 1. 函数名修改，功能变为检查API状态
func check_api_status():
	if speakers_request.is_processing():
		print("正在检查API状态，请稍候...")
		return
		
	var url
	if api_config["mode"] == "ip_port":
		url = "http://%s:%s%s" % [api_config.ip, str(api_config.port), api_config.speakers_path]
	else:
		url = api_config["website"] + api_config.speakers_path
	
	# 发送 GET 请求
	var error = speakers_request.request(url, [], HTTPClient.METHOD_GET)
	if error != OK:
		print("启动API状态检查请求时发生错误: ", error)

# [MODIFIED] 2. 完全重写此函数以适应新的API响应
func _on_speakers_request_completed(result, response_code, headers, body):
	# 首先处理请求失败的情况
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("检查API状态失败! 状态码: ", response_code)
		if body: print("错误信息: ", body.get_string_from_utf8())
		speaker_selector.clear()
		speaker_selector.add_item("API连接失败")
		speaker_selector.disabled = true
		self.disabled = true # 禁用合成按钮
		return
	
	# 解析返回的JSON
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		print("解析API状态JSON失败: ", json.get_error_message())
		speaker_selector.clear()
		speaker_selector.add_item("解析响应失败")
		speaker_selector.disabled = true
		self.disabled = true
		return
		
	var data = json.get_data()
	# 检查API是否为预期的XTTS模式
	if data is Dictionary and data.get("xtts_support") == true:
		print("API状态检查成功: XTTS模型已就绪，将使用默认参考音频。")
		# 更新UI以反映XTTS状态
		speaker_selector.clear()
		speaker_selector.add_item("默认声音 (XTTS)")
		speaker_selector.disabled = true # 因为没有其他选项，所以禁用选择器
		self.disabled = false # API可用，启用合成按钮
	else:
		print("API不支持XTTS或返回格式不正确。")
		print("收到的数据: ", data)
		speaker_selector.clear()
		speaker_selector.add_item("不支持XTTS")
		speaker_selector.disabled = true
		self.disabled = true


# 3. 当“合成语音”按钮被按下时调用
func _on_button_pressed():
	var text_to_speak = text_edit.text
	if text_to_speak.is_empty():
		print("文本内容为空，不发送请求。")
		return

	if tts_request.is_processing():
		print("正在处理上一个请求，请稍候...")
		return
		
	# [MODIFIED] 简化了检查逻辑，现在只依赖合成按钮自身的状态
	if self.is_disabled():
		print("合成功能当前不可用 (API未就绪)。")
		return

	send_tts_request(text_to_speak)


# [MODIFIED] 4. 准备并发送语音合成 API 请求 (简化版)
func send_tts_request(text: String):
	# [MODIFIED] 不再需要获取选择的说话人
	print("正在请求语音合成: '%s' (使用默认XTTS声音)" % text)
	
	# 创建请求头
	var headers = ["Content-Type: application/json"]
	
	# [MODIFIED] 创建请求体，现在只需要text字段
	var body_dict = {
		"text": text
	}
	var json_body = JSON.stringify(body_dict)
	
	# 构建URL并发送POST请求
	var url
	if api_config["mode"] == "ip_port":
		url = "http://%s:%s%s" % [api_config.ip, str(api_config.port), api_config.tts_path]
	else:
		url = api_config["website"] + api_config.tts_path
		
	var error = tts_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		print("启动语音合成请求时发生错误: ", error)


# 5. 当语音合成请求完成后调用 (此部分通常无需修改)
func _on_tts_request_completed(result, response_code, headers, body):
	print("语音合成请求完成! 状态码: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("API 请求失败!")
		print("错误信息: ", body.get_string_from_utf8())
		return

	# --- 重要假设 ---
	# 假设音频格式仍为WAV。如果播放失败，请根据新API文档调整以下参数。
	var audio_stream = AudioStreamWAV.new()
	audio_stream.data = body
	
	# 这些参数可能需要根据 API 的实际输出来调整
	# XTTS的默认输出通常是 24000Hz, 16-bit, 单声道
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS # 16位采样
	audio_stream.mix_rate = 24000 # XTTS 常用采样率
	audio_stream.stereo = false # 单声道
	
	audio_player.stream = audio_stream
	audio_player.play()
	print("音频已接收并开始播放。")
