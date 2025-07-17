extends AudioStreamPlayer

var effect: AudioEffectRecord
var recording: AudioStreamWAV

@onready var record_state_label = $"../RecordStateLabel"
@onready var record_button = $"../ToggleRecording"
@onready var recognition_status = $"../RecogStatus"

# 录音相关变量
var is_recording := false

# API配置缓存
var api_config = {
	"mode":"ip_port",
	"ip": "127.0.0.1",
	"port": 8000,
	"api_path": "/api/stt"
}

func _ready():
	# 加载API配置
	load_api_config()
	
	# 初始化录音系统
	init_recording_system()

func init_recording_system():
	# 获取Record总线
	var bus_idx = AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		push_error("Record bus not found! Please create a 'Record' bus with AudioEffectRecord.")
		return
	
	# 获取录音效果
	if AudioServer.get_bus_effect_count(bus_idx) > 0:
		effect = AudioServer.get_bus_effect(bus_idx, 0)
	else:
		push_error("No AudioEffectRecord found on Record bus!")

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
			if config.has("stt"):
				api_config["api_path"] = config["stt"]["api_path"]
				if config["stt"].has("website") and config["stt"]["website"]!="":
					api_config["website"] = config["stt"]["website"]
					api_config["mode"] = "web"
				elif config["stt"].has("ip") and config["stt"].has("port"):
					api_config["ip"] = config["stt"]["ip"]
					api_config["port"] = config["stt"]["port"]
			print("Loaded API config: ", api_config)
		else:
			push_error("Failed to parse config.json: " + json.get_error_message())
	else:
		push_error("Failed to open config.json")



func _on_record_button_pressed():
	if effect.is_recording_active():
		# 停止录音并获取数据
		recording = effect.get_recording()
		effect.set_recording_active(false)
		is_recording = false
		record_button.text = "自动检测"
		record_state_label.text = "[color=red]已停止[/color]"
		
		# 上传录音
		upload_recording()
	else:
		# 开始录音（覆盖之前的录音）
		effect.set_recording_active(true)
		is_recording = true
		record_button.text = "停止录音"
		record_state_label.text = "[color=green]录音中...[/color]"

# 生成完整的WAV文件数据（包含文件头）
func get_wav_data() -> PackedByteArray:
	if not recording:
		return PackedByteArray()
	
	# 获取原始PCM数据
	var pcm_data: PackedByteArray = recording.data
	
	# WAV文件头
	var header = PackedByteArray([
		0x52, 0x49, 0x46, 0x46, # "RIFF"
		0x00, 0x00, 0x00, 0x00, # 文件大小占位符
		0x57, 0x41, 0x56, 0x45, # "WAVE"
		0x66, 0x6D, 0x74, 0x20, # "fmt "
		0x10, 0x00, 0x00, 0x00, # fmt区块大小
		0x01, 0x00,			 # 音频格式(PCM)
		0x01, 0x00,			 # 单声道
		0x44, 0xAC, 0x00, 0x00, # 采样率(44100)
		0x88, 0x58, 0x01, 0x00, # 字节率(44100*2)
		0x02, 0x00,			 # 块对齐(2 bytes/sample)
		0x10, 0x00,			 # 位深(16-bit)
		0x64, 0x61, 0x74, 0x61, # "data"
		0x00, 0x00, 0x00, 0x00  # 数据大小占位符
	])
	
	# 计算文件大小和数据大小
	var data_size = pcm_data.size()
	var file_size = data_size + 36  # 文件头36字节
	
	# 更新文件大小 (小端序)
	header[4] = file_size & 0xFF
	header[5] = (file_size >> 8) & 0xFF
	header[6] = (file_size >> 16) & 0xFF
	header[7] = (file_size >> 24) & 0xFF
	
	# 更新数据大小 (小端序)
	header[40] = data_size & 0xFF
	header[41] = (data_size >> 8) & 0xFF
	header[42] = (data_size >> 16) & 0xFF
	header[43] = (data_size >> 24) & 0xFF
	
	# 组合头和音频数据
	var wav_data = PackedByteArray()
	wav_data.append_array(header)
	wav_data.append_array(pcm_data)
	
	return wav_data

# 上传录音到API (使用multipart/form-data格式)
func upload_recording():
	if not recording:
		push_error("No recording available!")
		return
	
	print("save to debug.wav")
	recording.save_to_wav("user://debug.wav")
	
	# 1. 获取WAV数据
	recognition_status.text = "getting wave data"
	var wav_data = get_wav_data()
	if wav_data.is_empty():
		push_error("Failed to generate WAV data")
		return
	
	# 2. 构建multipart/form-data请求体
	var boundary = "----WebKitFormBoundary" + str(randi()).sha1_text().substr(0, 16)
	# var body = PackedByteArray()
	
	# 构建表单字段
	var form_data = PackedByteArray()
	
	# 音频文件部分
	form_data.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	form_data.append_array('Content-Disposition: form-data; name="audio"; filename="recording.wav"\r\n'.to_utf8_buffer())
	form_data.append_array("Content-Type: audio/wav\r\n\r\n".to_utf8_buffer())
	form_data.append_array(wav_data)
	form_data.append_array("\r\n".to_utf8_buffer())
	
	# 结束边界
	form_data.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())
	
	# 3. 准备HTTP请求
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed.bind(http_request))
	
	# 4. 构建API URL
	var url
	if api_config["mode"] == "ip_port":
		url = "http://%s:%s%s" % [api_config.ip, str(api_config.port), api_config.api_path]
	else:
		url = api_config["website"] + api_config["api_path"]
	
	# 5. 设置请求头 - multipart/form-data格式
	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary,
		"Accept: application/json",
		"Content-Length: " + str(form_data.size())
	]
	
	# 6. 发送POST请求
	recognition_status.text = "Sending http request to " + url
	var error = http_request.request_raw(url, headers, HTTPClient.METHOD_POST, form_data)
	if error != OK:
		push_error("HTTP request failed: " + str(error))
		http_request.queue_free()

# 处理API响应
func _on_request_completed(result, response_code, _headers, body, http_request):
	# 移除HTTPRequest节点
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Request failed with result: " + str(result))
		return
	
	if response_code != 200:
		push_error("API returned non-200 status: " + str(response_code))
		return
	
	# 解析JSON响应
	recognition_status.text = "Parsing result..."
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	
	if parse_error != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return
	
	var response_data = json.get_data()
	
	# 处理转写结果
	if response_data.has("text"):
		var confidence = response_data.get("confidence", 0.0)
		var processing_time = response_data.get("processing_time", 0.0)
		
		print("--- Speech-to-Text Result ---")
		print("Text: ", response_data["text"])
		print("Confidence: %.2f%%" % (confidence * 100))
		print("Processing Time: %.2f seconds" % processing_time)
		
		# 在这里添加你处理文本的逻辑
		# 例如：显示在UI上、保存到文件等
		display_result(response_data["text"], confidence)
	else:
		push_error("Invalid API response format")

# 示例：显示结果
func display_result(text: String, confidence: float):
	$"../ContextEdit".text += text
	recognition_status.text = "result confidence %.1f%%" % (confidence * 100)
	


func _on_play_button_pressed():
	$AudioStreamPlayer.stream = recording  # 绑定到AudioStreamPlayer节点
	$AudioStreamPlayer.play()
