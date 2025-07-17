import requests

# Your TTS API endpoint
TTS_API_URL = "http://192.168.0.246:8000/api/tts"
TTS_SPEAKERS_URL = "http://192.168.0.246:8000/api/tts/speakers"

# Text to synthesize
text = "你好，这是一个中文语音合成测试。"

def get_available_speakers():
    """获取可用的说话人列表"""
    try:
        response = requests.get(TTS_SPEAKERS_URL)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"⚠ Failed to get speakers: {response.status_code}")
            return None
    except Exception as e:
        print(f"⚠ Error getting speakers: {e}")
        return None

# 获取说话人信息
print("▶ Getting available speakers...")
speakers_info = get_available_speakers()
if speakers_info:
    print(f"✅ Available speakers: {speakers_info}")
    default_speaker = speakers_info.get('default_speaker')
else:
    default_speaker = None

# Request payload
payload = {
    "text": text,
    "voice": "default",
    "speed": 1.0
}

# 如果有默认说话人，添加到payload中
if default_speaker:
    payload["speaker"] = default_speaker
    print(f"🎤 Using speaker: {default_speaker}")

try:
    print("▶ Sending request to TTS API...")
    response = requests.post(TTS_API_URL, json=payload, stream=True)
    
    if response.status_code == 200:
        output_path = "output_tts.wav"
        with open(output_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        print(f"✅ Audio saved successfully to: {output_path}")
        
        # Optional: play audio (Windows only)
        try:
            import playsound
            print("🎧 Playing the synthesized audio...")
            playsound.playsound(output_path)
        except ImportError:
            print("🔊 Audio file saved. To auto-play, install `playsound` with: pip install playsound")
    else:
        print(f"❌ Request failed with HTTP {response.status_code}")
        print(response.text)
except Exception as e:
    print(f"⚠ Error occurred: {e}")