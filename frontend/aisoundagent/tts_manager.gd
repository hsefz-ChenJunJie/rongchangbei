extends Node
# 初始化 TTS
var voice_id
var has_tts = false
func _ready():
	# 启用 TTS 后获取语音
	var path_to_tts = "audio/general/text_to_speech"
	if ProjectSettings.has_setting(path_to_tts):
		has_tts = ProjectSettings.get_setting(path_to_tts)
	if has_tts:
		var voices = DisplayServer.tts_get_voices_for_language("zh")
		if voices.size() > 0:
			voice_id = voices[0]  # 存储到全局变量
		if voices.size() > 1:
			voice_id = voices[1]  # 存储到全局变量

# 朗读函数
func speak(text: String):
	if has_tts:
		if voice_id != "":
			DisplayServer.tts_stop()  # 可选：中断前一条
			DisplayServer.tts_speak(text, voice_id)
