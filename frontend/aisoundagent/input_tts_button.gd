extends Button

# ！！！！重要！！！！
# 请根据您在场景中的实际节点路径进行修改
# 1. TextEdit: 用于输入文本
@onready var text_edit: TextEdit = $"../TextEdit"
# 2. TTS_Request: 用于发送文本转语音请求
@onready var tts_request: HTTPRequest = $TTS_Request
# 3. Speakers_Request: 用于获取可用说话人列表
@onready var speakers_request: HTTPRequest = $Speaker_Request
# 4. AudioStreamPlayer: 用于播放合成的音频
@onready var audio_player: AudioStreamPlayer = $"../../Panel/RecordControl/AudioStreamPlayer"
# 5. SpeakerSelector: 用于显示和选择说话人 (这是一个 OptionButton 节点)
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
	
	# 加载外部配置并获取说话人列表
	load_api_config()
	fetch_speaker_list()
	

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


# 1. 获取可用的说话人列表
func fetch_speaker_list():
	if speakers_request.is_processing():
		print("正在获取说话人列表，请稍候...")
		return
		
	var url
	if api_config["mode"] == "ip_port":
		url = "http://%s:%s%s" % [api_config.ip, str(api_config.port), api_config.speakers_path]
	else:
		url = api_config["website"] + api_config.speakers_path
	
	# 发送 GET 请求
	var error = speakers_request.request(url, [], HTTPClient.METHOD_GET)
	if error != OK:
		print("启动获取说话人列表请求时发生错误: ", error)

# 2. 当获取说话人列表的请求完成时调用
func _on_speakers_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("获取说话人列表失败! 状态码: ", response_code)
		print("错误信息: ", body.get_string_from_utf8())
		speaker_selector.clear()
		speaker_selector.add_item("获取列表失败")
		speaker_selector.disabled = true
		#self.disabled = true # 禁用合成按钮
		return
	
	print(body.get_string_from_utf8())
	# 解析返回的JSON
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		print("解析说话人列表JSON失败: ", json.get_error_message())
		return
		
	var data = json.get_data()
	if not data is Dictionary or not data.has("speakers"):
		print("返回的说话人JSON格式不正确。原始数据: ", data)
		return
		
	var speaker_list: Array = data["speakers"]
	
	# 清空并检查说话人列表
	speaker_selector.clear()
	if speaker_list.is_empty():
		print("警告: API返回的说话人列表为空。")
		speaker_selector.add_item("无可用说话人")
		speaker_selector.disabled = true
		#self.disabled = true # 列表为空时禁用合成按钮
		return
	
	# 如果之前被禁用了，现在重新启用
	speaker_selector.disabled = false
	self.disabled = false
	
	# 填充 OptionButton
	for speaker_name in speaker_list:
		speaker_selector.add_item(speaker_name)
	
	# 安全地获取和设置默认说话人
	var default_speaker = data.get("default_speaker") # 使用 .get() 防止键不存在的错误
	
	if default_speaker != null:
		var default_index = speaker_list.find(default_speaker)
		if default_index != -1:
			speaker_selector.select(default_index)
		else:
			speaker_selector.select(0) # 如果默认值不在列表中，选择第一个
	else:
		speaker_selector.select(0) # 如果没有提供默认值，选择第一个
	
	print("说话人列表已成功加载并更新。")


# 3. 当“合成语音”按钮被按下时调用
func _on_button_pressed():
	var text_to_speak = text_edit.text
	if text_to_speak.is_empty():
		print("文本内容为空，不发送请求。")
		return

	if tts_request.is_processing():
		print("正在处理上一个请求，请稍候...")
		return
		
	# 增加检查，防止在没有有效说话人时发送请求
	if speaker_selector.is_disabled() or speaker_selector.item_count == 0:
		TtsManager.speak(text_to_speak)
		return

	send_tts_request(text_to_speak)
	


# 4. 准备并发送语音合成 API 请求
func send_tts_request(text: String):
	var selected_speaker = speaker_selector.get_item_text(speaker_selector.selected)
	print("正在请求语音合成: '%s' (说话人: %s)" % [text, selected_speaker])
	
	# 创建请求头
	var headers = ["Content-Type: application/json"]
	
	# 创建请求体 (根据新版API文档)
	var body_dict = {
		"text": text,
		"speaker": selected_speaker
		# "voice" 字段在文档中存在但作用不明，这里我们优先使用更明确的 "speaker" 字段。
		# 如果API需要，可以取消下面这行的注释:
		# "voice": "default"
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


# 5. 当语音合成请求完成后调用
func _on_tts_request_completed(result, response_code, headers, body):
	print("语音合成请求完成! 状态码: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("API 请求失败!")
		print("错误信息: ", body.get_string_from_utf8())
		return

	# --- 重要假设 ---
	# API文档未明确返回的音频格式，我们继续假设是WAV。
	# 如果播放失败或有噪音，您可能需要根据API的实际输出来调整。
	var audio_stream = AudioStreamWAV.new()
	audio_stream.data = body
	
	# 这些参数也需要根据 API 的实际输出进行调整
	# 如果播放的声音速度不对或者很刺耳，请尝试修改这些值
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS # 16位采样
	audio_stream.mix_rate = 22050 # 采样率 (Coqui TTS的常用值)
	audio_stream.stereo = false # 单声道
	
	audio_player.stream = audio_stream
	audio_player.play()
	print("音频已接收并开始播放。")
