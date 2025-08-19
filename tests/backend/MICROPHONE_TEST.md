# 麦克风语音转文字测试说明

## 📋 功能概述

这是一个专门的麦克风语音转文字测试程序，用于验证AI对话应用后端的STT（语音转文字）功能。该测试程序：

- 🎤 **调用本地麦克风**：实时录制您的声音
- 📡 **发送音频流**：通过WebSocket将音频数据发送到远程后端
- 🔄 **实时处理**：后端使用Whisper或Vosk进行语音识别
- 📝 **显示结果**：展示识别出的文字内容
- 📊 **详细日志**：集成现有测试框架的事件日志系统

## 🚀 快速开始

### 1. 安装依赖

```bash
# 运行依赖安装脚本
python install_microphone_test_deps.py
```

### 2. 配置服务器地址

编辑 `remote_test_config.json` 文件，确保服务器地址正确：

```json
{
  "backend_server": {
    "base_url": "http://your-server-ip",
    "port": 8000,
    "websocket_endpoint": "/conversation"
  },
  "microphone_test": {
    "record_seconds": 10,
    "sample_rate": 16000,
    "channels": 1
  }
}
```

### 3. 运行测试

```bash
python test_microphone_stt.py
```

## ⚙️ 配置选项

### 麦克风配置 (`microphone_test`)

#### 音频设置
| 配置项 | 说明 | 默认值 | 推荐值 |
|--------|------|--------|--------|
| `channels` | 声道数（1=单声道，2=立体声） | 1 | 1 |
| `sample_rate` | 采样率（Hz） | 16000 | 16000 |
| `chunk_size` | 音频块大小 | 1024 | 1024-2048 |
| `record_seconds` | 录音时长（秒） | 10 | 5-15 |
| `audio_format` | 音频格式（PyAudio常量） | 8 | 8 (16位) |

#### 超时和重试设置
| 配置项 | 说明 | 默认值 | 推荐值 |
|--------|------|--------|--------|
| `transcription_timeout` | 等待转录结果超时（秒） | 15.0 | 10-30 |
| `opinion_timeout` | 等待意见建议超时（秒） | 10.0 | 5-15 |
| `transcription_max_attempts` | 转录事件最大重试次数 | 20 | 15-30 |
| `opinion_max_attempts` | 意见事件最大重试次数 | 15 | 10-20 |
| `progress_display_interval` | 进度显示间隔（音频块数） | 10 | 5-20 |

#### 高级设置
| 配置项 | 说明 | 默认值 | 用途 |
|--------|------|--------|------|
| `silence_threshold` | 静音检测阈值 | 500 | 静音检测 |
| `silence_duration` | 静音持续时间（秒） | 2.0 | 自动停止录音 |

### 服务器配置

使用现有的 `backend_server` 配置段：

```json
{
  "backend_server": {
    "base_url": "http://localhost",
    "port": 8000,
    "websocket_endpoint": "/conversation"
  }
}
```

## 🎯 测试流程

1. **环境检查**
   - 检测音频设备
   - 验证麦克风权限
   - 测试服务器连接

2. **建立连接**
   - HTTP健康检查
   - WebSocket连接
   - 创建对话会话

3. **音频录制**
   - 用户确认开始录音
   - 实时录制10秒音频
   - 将音频流发送到后端

4. **语音识别**
   - 后端处理音频数据
   - STT服务转换为文字
   - 返回识别结果

5. **结果展示**
   - 显示转录文本
   - 生成测试报告
   - 事件日志记录

## 📊 输出示例

```
🎯 麦克风语音转文字测试程序
基于远程API测试框架
============================================================

🎤 麦克风测试配置:
   采样率: 16000Hz
   声道数: 1
   录音时长: 10秒
   音频块大小: 1024

🎧 检测到 3 个音频设备
🎤 默认输入设备: MacBook Pro Microphone
📊 最大输入声道数: 1
🔊 默认采样率: 44100.0

⚙️ 测试配置:
   目标服务器: http://xg.3.frp.one:40271
   WebSocket地址: ws://xg.3.frp.one:40271/conversation

🚀 开始 麦克风语音转文字测试
============================================================

🔗 测试服务器连接...
✅ HTTP连接测试成功

🔌 建立WebSocket连接...
✅ WebSocket连接成功

📞 启动对话会话...
✅ 会话创建成功，ID: session_abc123

📝 发送消息开始事件...

🎤 准备开始录音...
⏱️ 录音时长: 10 秒
🗣️ 请清晰地说话，比如：'你好，这是一个语音转文字测试'
🔊 请确保在安静的环境中进行测试

按回车键开始录音...

🔴 录音中... (10秒)
🎵 开始发送音频流...
📊 已发送 10 个音频块，最近10块耗时: 0.15秒
📊 已发送 20 个音频块，最近10块耗时: 0.14秒
...
✅ 音频流发送完成，总共发送 156 个音频块

📤 发送消息结束事件...

⏳ 等待语音转录结果（最多15秒）...
🔄 正在处理语音转文字...
✅ 消息已记录，转录完成

🎉 测试成功完成！
📝 转录结果: 转录已完成（具体文本内容需要后端支持返回）

📄 测试报告已保存: microphone_stt_test_report_20250819_102345.json
✅ 麦克风语音转文字测试成功完成！
```

## 🔧 故障排除

### 常见问题

1. **PyAudio安装失败**
   ```
   ❌ PyAudio未安装
   ```
   **解决方案**：
   - macOS: `brew install portaudio && pip install pyaudio`
   - Linux: `sudo apt-get install portaudio19-dev && pip install pyaudio`
   - Windows: `pip install pyaudio`（通常直接可用）

2. **麦克风权限被拒绝**
   ```
   ❌ 录音启动失败: [Errno -9997] Invalid sample rate
   ```
   **解决方案**：
   - macOS: 系统偏好设置 → 安全性与隐私 → 麦克风 → 授权Terminal/IDE
   - Linux: 确保用户在audio组：`sudo usermod -a -G audio $USER`

3. **WebSocket连接失败**
   ```
   ❌ WebSocket连接失败
   ```
   **解决方案**：
   - 检查服务器地址和端口
   - 确认后端服务正在运行
   - 验证防火墙设置

4. **音频设备问题**
   ```
   ❌ 无法获取默认输入设备信息
   ```
   **解决方案**：
   - 检查麦克风是否正常工作
   - 尝试其他音频应用是否可以录音
   - 重启音频服务

### 调试技巧

1. **启用详细日志**
   ```json
   {
     "test_settings": {
       "enable_detailed_logging": true,
       "log_level": "DEBUG"
     }
   }
   ```

2. **调整录音参数**
   ```json
   {
     "microphone_test": {
       "record_seconds": 5,
       "sample_rate": 8000,
       "chunk_size": 512
     }
   }
   ```

3. **测试步骤**
   ```bash
   # 1. 先测试音频设备
   python -c "import pyaudio; p=pyaudio.PyAudio(); print(f'设备数量: {p.get_device_count()}'); p.terminate()"
   
   # 2. 测试服务器连接
   curl http://your-server:8000/
   
   # 3. 运行完整测试
   python test_microphone_stt.py
   ```

## 📋 系统要求

- **Python**: 3.8+
- **操作系统**: macOS/Linux/Windows
- **音频设备**: 支持录音的麦克风
- **网络**: 能访问后端服务器
- **权限**: 麦克风访问权限

## 🔄 与现有测试框架的集成

该测试完全集成了现有的远程API测试框架：

- ✅ **继承RemoteTestBase**：使用统一的配置和日志系统
- ✅ **事件日志系统**：自动记录所有WebSocket事件
- ✅ **测试报告**：生成JSON格式的详细测试报告
- ✅ **配置管理**：使用remote_test_config.json统一配置
- ✅ **错误处理**：统一的异常处理和重试机制

## 📞 技术支持

如果遇到问题：

1. **查看日志**：检查生成的测试报告和事件日志
2. **检查配置**：验证remote_test_config.json格式
3. **测试网络**：确认到服务器的连接
4. **音频测试**：使用系统录音软件验证麦克风
5. **权限检查**：确认麦克风和网络权限

---

这个测试工具为语音转文字功能提供了完整的端到端验证，帮助您快速确认STT服务是否正常工作。