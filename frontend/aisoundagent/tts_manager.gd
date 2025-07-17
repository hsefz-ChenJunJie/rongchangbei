extends Node
# 初始化 TTS
var voice_id
func _ready():
	# 启用 TTS 后获取语音
	var voices = DisplayServer.tts_get_voices_for_language("zh")
	if voices.size() > 0:
		voice_id = voices[0]  # 存储到全局变量
	if voices.size() > 1:
		voice_id = voices[1]  # 存储到全局变量

# 朗读函数
func speak(text: String):
	if voice_id != "":
		DisplayServer.tts_stop()  # 可选：中断前一条
		DisplayServer.tts_speak(text, voice_id)
