import sounddevice as sd
import wavio
import numpy as np

# --- 设置录音参数 ---
samplerate = 44100  # 采样率 (Hz)
duration = 5        # 录音时长 (秒)
channels = 1        # 声道数 (1: 单声道, 2: 立体声)
filename = "recording.wav" # 保存的文件名

print("录音开始...")

# 开始录音
# sd.rec() 会返回一个 NumPy 数组
recording = sd.rec(int(duration * samplerate), samplerate=samplerate, channels=channels, dtype='int16')

# 等待录音完成
sd.wait()

print("录音结束。")

# 保存为 WAV 文件
# wavio.write() 需要文件名、数据、采样率和样本宽度
print(f"正在保存录音至 {filename}...")
wavio.write(filename, recording, samplerate, sampwidth=2) # sampwidth=2 表示16位

print("文件保存成功！")