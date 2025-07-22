extends Node2D

var effect_record: AudioEffectRecord
var recording: AudioStreamWAV
var record_bus_idx: int

func _ready():
	# 获取录音总线及效果
	record_bus_idx = AudioServer.get_bus_index("RecordBus")
	effect_record = AudioServer.get_bus_effect(record_bus_idx, 0)
	# 初始化麦克风播放器
	$Audio/MicPlayer.stream = AudioStreamMicrophone.new()
	$Audio/MicPlayer.play()  # 持续接收麦克风输入

func _on_RecordButton_pressed():
	if effect_record.is_recording_active():
		# 停止录音
		recording = effect_record.get_recording()
		effect_record.set_recording_active(false)
		$UI/PlayButton.disabled = false
		$UI/SaveButton.disabled = false
		$UI/RecordButton.text = "开始录音"
		$UI/StatusLabel.text = "已停止"
	else:
		# 开始录音
		$UI/PlayButton.disabled = true
		$UI/SaveButton.disabled = true
		effect_record.set_recording_active(true)
		$UI/RecordButton.text = "停止录音"
		$UI/StatusLabel.text = "录音中..."

func _on_PlayButton_pressed():
	if recording:
		$Audio/PlaybackPlayer.stream = recording
		$Audio/PlaybackPlayer.play()

func _on_SaveButton_pressed():
	recording.save_to_wav("user://test_recording.wav")
	$UI/StatusLabel.text = "已保存至：user://test_recording.wav"

# 实时音量监测（每帧更新）
func _process(_delta):
	var mic_volume = AudioServer.get_bus_peak_volume_left_db(record_bus_idx, 0)
	$UI/VolumeMeter.material.set_shader_param("volume", mic_volume)
