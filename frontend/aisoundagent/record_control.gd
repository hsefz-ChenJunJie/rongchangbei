extends Control

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
				if config["stt"].has("website"):
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

# 上传录音到API - 修正版
func upload_recording():
	if not recording:
		push_error("No recording available!")
		return
	
	# 1. 直接在内存中构建WAV格式的二进制数据
	recognition_status.text = "Construct Binary file"
	var wav_data = get_wav_data(recording)
	if wav_data.is_empty():
		push_error("Failed to generate WAV data")
		return
	
	# 2. 准备HTTP请求
	recognition_status.text = "Preparing HTTP Request"
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed.bind(http_request))
	
	# 3. 构建API URL
	var url = "http://%s:%s%s" % [api_config["ip"], str(api_config["port"]), api_config["api_path"]]
	
	# 4. 设置请求头 - 指定音频格式
	var headers = [
		"Content-Type: audio/wav",
		"Accept: application/json"
	]
	
	# 5. 使用request_raw方法发送二进制数据
	recognition_status.text = "Sending binary files to " + url
	var error = http_request.request_raw(url, headers, HTTPClient.METHOD_POST, wav_data)
	if error != OK:
		push_error("HTTP request failed: " + str(error))
		http_request.queue_free()

# 生成WAV格式的二进制数据
func get_wav_data(stream: AudioStreamWAV) -> PackedByteArray:
	# 直接使用AudioStreamWAV中的完整WAV数据
	return stream.data

# 处理API响应
func _on_request_completed(result, response_code, headers, body, http_request):
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
