# AI对话应用后端 - 详细配置说明

## 配置概述

本文档详细说明了AI对话应用后端的所有48个可配置项，包括环境变量、配置文件选项、默认值和最佳实践建议。

## 配置方式

配置系统基于 Pydantic Settings，支持多种配置方式：

1. **环境变量** - 推荐生产环境使用
2. **`.env` 文件** - 推荐开发环境使用  
3. **代码默认值** - 系统内置默认值

优先级：环境变量 > .env文件 > 代码默认值

## 完整配置清单

后端系统共包含 **48个配置项**，分为以下8个功能分类：

### 🔗 OpenRouter LLM API 配置（5项）

用于集成 OpenRouter 大语言模型服务，支持多种AI模型调用。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `openrouter_api_key` | `OPENROUTER_API_KEY` | str | `None` | 否 | OpenRouter API密钥，未配置时使用Mock模式 |
| `openrouter_base_url` | `OPENROUTER_BASE_URL` | str | `https://openrouter.ai/api/v1` | 否 | OpenRouter API基础URL |
| `openrouter_model` | `OPENROUTER_MODEL` | str | `anthropic/claude-3-haiku` | 否 | 使用的AI模型名称 |
| `openrouter_temperature` | `OPENROUTER_TEMPERATURE` | float | `0.7` | 否 | 模型温度参数（0.0-2.0） |
| `openrouter_max_tokens` | `OPENROUTER_MAX_TOKENS` | int | `800` | 否 | 单次请求最大token数 |

**配置示例：**
```bash
# 生产环境配置
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxx
OPENROUTER_MODEL=anthropic/claude-3-sonnet
OPENROUTER_TEMPERATURE=0.5
OPENROUTER_MAX_TOKENS=1000

# 开发环境配置（使用Mock模式）
# OPENROUTER_API_KEY=  # 留空或不设置
```

**模型选择建议：**
- `anthropic/claude-3-haiku` - 快速响应，成本较低
- `anthropic/claude-3-sonnet` - 平衡性能和成本
- `openai/gpt-4o-mini` - OpenAI经济型模型
- `openai/gpt-4o` - OpenAI高性能模型

### 🎙️ STT 语音识别服务配置（16项）

支持多种语音转文字服务，包括Whisper和Vosk，可通过配置动态选择。

#### STT服务选择配置（1项）

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `stt_engine` | `STT_ENGINE` | str | `whisper` | 否 | STT引擎选择（mock/whisper/vosk） |

#### Whisper STT 配置（13项）

用于集成 Whisper 本地语音转文字服务，支持GPU/CPU推理和多种优化选项。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `use_whisper` | `USE_WHISPER` | bool | `True` | 否 | 是否启用Whisper服务（兼容性） |
| `whisper_model_name` | `WHISPER_MODEL_NAME` | str | `base` | 否 | Whisper模型名称 |
| `whisper_model_path` | `WHISPER_MODEL_PATH` | str | `model/whisper-models` | 否 | Whisper模型存储目录 |
| `whisper_device` | `WHISPER_DEVICE` | str | `auto` | 否 | 推理设备（auto/cpu/cuda） |
| `whisper_compute_type` | `WHISPER_COMPUTE_TYPE` | str | `int8` | 否 | 计算精度类型 |
| `whisper_batch_size` | `WHISPER_BATCH_SIZE` | int | `16` | 否 | 批处理大小 |
| `whisper_beam_size` | `WHISPER_BEAM_SIZE` | int | `5` | 否 | 束搜索大小 |
| `whisper_language` | `WHISPER_LANGUAGE` | str | `null` | 否 | 强制语言识别（null为自动） |
| `whisper_vad_filter` | `WHISPER_VAD_FILTER` | bool | `True` | 否 | 启用语音活动检测 |
| `whisper_word_timestamps` | `WHISPER_WORD_TIMESTAMPS` | bool | `False` | 否 | 生成词级时间戳 |
| `whisper_temperature` | `WHISPER_TEMPERATURE` | float | `0.0` | 否 | 采样温度（0为贪婪解码） |
| `whisper_condition_on_previous_text` | `WHISPER_CONDITION_ON_PREVIOUS_TEXT` | bool | `True` | 否 | 基于前文条件推理 |
| `whisper_progressive_transcription_seconds` | `WHISPER_PROGRESSIVE_TRANSCRIPTION_SECONDS` | `float` | `1.0` | 否 | 渐进式转录的缓冲区时长（秒）。每次累积的音频达到该时长时，就会进行一次处理。 |

#### Vosk STT 配置（3项）

用于集成 Vosk 本地语音转文字服务作为备用选项。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `use_real_vosk` | `USE_REAL_VOSK` | bool | `False` | 否 | 是否启用Vosk STT服务（兼容性） |
| `vosk_model_path` | `VOSK_MODEL_PATH` | str | `model/vosk-model` | 否 | Vosk模型文件路径 |
| `vosk_sample_rate` | `VOSK_SAMPLE_RATE` | int | `16000` | 否 | 音频采样率（Hz） |

**STT引擎选择示例：**
```bash
# 使用Whisper（推荐）
STT_ENGINE=whisper
USE_WHISPER=true

# 使用Vosk作为备用
STT_ENGINE=vosk
USE_REAL_VOSK=true

# 开发测试使用Mock
STT_ENGINE=mock
```

**Whisper配置示例：**
```bash
# 基础配置（推荐）
WHISPER_MODEL_NAME=base
WHISPER_DEVICE=auto
WHISPER_COMPUTE_TYPE=int8

# CPU优化配置
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8
WHISPER_BATCH_SIZE=8

# GPU高性能配置
WHISPER_DEVICE=cuda
WHISPER_COMPUTE_TYPE=float16
WHISPER_BATCH_SIZE=32

# 高精度配置
WHISPER_MODEL_NAME=medium
WHISPER_COMPUTE_TYPE=float32
WHISPER_BEAM_SIZE=10
WHISPER_WORD_TIMESTAMPS=true
```

**Vosk配置示例：**
```bash
# 使用中文模型
VOSK_MODEL_PATH=model/vosk-model-cn-0.22

# 使用英文模型  
VOSK_MODEL_PATH=model/vosk-model-small-en-us-0.15

# 高质量音频
VOSK_SAMPLE_RATE=44100
```

**Whisper模型选择建议：**
- `tiny` (~39MB) - 快速测试，准确率较低
- `base` (~74MB) - **通用推荐**，平衡性能和准确率
- `small` (~244MB) - 高质量需求
- `medium` (~769MB) - 专业应用
- `large-v3` (~1550MB) - 最高精度

**Whisper设备选择建议：**
- `auto` - 自动检测最佳设备（推荐）
- `cpu` - CPU推理，内存需求1-10GB
- `cuda` - GPU推理，需要CUDA支持

**Vosk模型下载建议：**
- 中文识别：`vosk-model-cn-0.22` (~500MB)
- 英文识别：`vosk-model-en-us-0.22` (~1.8GB)
- 小型英文：`vosk-model-small-en-us-0.15` (~40MB)

### 🌐 服务器网络配置（4项）

控制 FastAPI 应用的网络监听和访问设置。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `host` | `HOST` | str | `127.0.0.1` | 否 | 服务器监听地址 |
| `port` | `PORT` | int | `8000` | 否 | 服务器监听端口 |
| `debug` | `DEBUG` | bool | `True` | 否 | 调试模式开关 |
| `allowed_origins` | `ALLOWED_ORIGINS` | List[str] | `["*"]` | 否 | CORS允许的域名列表 |

**配置示例：**
```bash
# 开发环境
HOST=127.0.0.1
PORT=8000
DEBUG=true

# 生产环境
HOST=0.0.0.0
PORT=8000  
DEBUG=false

# 自定义端口
PORT=3000
```

**网络配置建议：**
- 开发环境：`HOST=127.0.0.1` 仅本地访问
- 生产环境：`HOST=0.0.0.0` 允许外部访问
- 容器环境：必须使用 `HOST=0.0.0.0`

### ⏱️ 超时设置（7项）

控制各种服务操作的超时时间，防止长时间阻塞。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `stt_timeout` | `STT_TIMEOUT` | int | `30` | 否 | STT服务超时时间（秒） |
| `llm_timeout` | `LLM_TIMEOUT` | int | `30` | 否 | LLM服务超时时间（秒） |
| `websocket_timeout` | `WEBSOCKET_TIMEOUT` | int | `600` | 否 | WebSocket连接超时时间（秒） |
| `websocket_ping_interval` | `WEBSOCKET_PING_INTERVAL` | int | `30` | 否 | WebSocket心跳间隔时间（秒） |
| `websocket_ping_timeout` | `WEBSOCKET_PING_TIMEOUT` | int | `10` | 否 | WebSocket心跳超时时间（秒） |
| `websocket_max_message_size` | `WEBSOCKET_MAX_MESSAGE_SIZE` | int | `16777216` | 否 | WebSocket最大消息大小（字节） |
| `timeout` | `TIMEOUT` | int | `60` | 否 | 通用超时时间（秒） |

**配置示例：**
```bash
# 快速响应配置
STT_TIMEOUT=15
LLM_TIMEOUT=20
WEBSOCKET_TIMEOUT=180

# 宽松超时配置  
STT_TIMEOUT=60
LLM_TIMEOUT=90
WEBSOCKET_TIMEOUT=600
```

**超时设置建议：**
- STT超时：通常15-30秒足够
- LLM超时：根据模型复杂度调整20-60秒
- WebSocket：建议300-600秒

### 📝 日志记录配置（5项）

控制应用日志的输出级别和格式。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `log_level` | `LOG_LEVEL` | str | `INFO` | 否 | 日志级别 |
| `log_format` | `LOG_FORMAT` | str | `json` | 否 | 日志输出格式 |
| `log_file` | `LOG_FILE` | str | `logs/app.log` | 否 | 日志文件路径 |
| `log_max_size` | `LOG_MAX_SIZE` | str | `100MB` | 否 | 日志文件最大大小 |
| `log_backup_count` | `LOG_BACKUP_COUNT` | int | `5` | 否 | 日志备份文件数量 |

**可选值：**
- **日志级别**: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- **日志格式**: `json`, `text`

**配置示例：**
```bash
# 开发环境 - 详细日志
LOG_LEVEL=DEBUG
LOG_FORMAT=text

# 生产环境 - 结构化日志
LOG_LEVEL=INFO  
LOG_FORMAT=json

# 错误排查
LOG_LEVEL=DEBUG
```

**日志级别说明：**
- `DEBUG`: 最详细，包含调试信息
- `INFO`: 一般信息，推荐生产环境
- `WARNING`: 警告信息
- `ERROR`: 仅错误信息
- `CRITICAL`: 仅严重错误

### 🎵 音频处理配置（6项）

控制音频数据的处理参数和背压控制。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `audio_chunk_size` | `AUDIO_CHUNK_SIZE` | int | `4096` | 否 | 音频数据块大小（字节） |
| `audio_sample_rate` | `AUDIO_SAMPLE_RATE` | int | `16000` | 否 | 音频采样率（Hz） |
| `audio_channels` | `AUDIO_CHANNELS` | int | `1` | 否 | 音频声道数 |
| `audio_buffer_max_size` | `AUDIO_BUFFER_MAX_SIZE` | int | `52428800` | 否 | 音频缓冲区最大大小（50MB） |
| `audio_buffer_cleanup_interval` | `AUDIO_BUFFER_CLEANUP_INTERVAL` | int | `10` | 否 | 音频缓冲区清理间隔（秒） |
| `audio_max_chunks_per_second` | `AUDIO_MAX_CHUNKS_PER_SECOND` | int | `100` | 否 | 每秒最大音频块数量（背压控制） |

**配置示例：**
```bash
# 标准配置
AUDIO_CHUNK_SIZE=4096
AUDIO_SAMPLE_RATE=16000  
AUDIO_CHANNELS=1

# 高质量音频
AUDIO_CHUNK_SIZE=8192
AUDIO_SAMPLE_RATE=44100
AUDIO_CHANNELS=2

# 低延迟配置
AUDIO_CHUNK_SIZE=2048
AUDIO_SAMPLE_RATE=8000
```

**音频参数建议：**
- 实时对话：16kHz, 单声道, 4KB块
- 高质量录音：44.1kHz, 立体声, 8KB块
- 低带宽：8kHz, 单声道, 2KB块

### ⚡ 性能配置（1项）

控制应用的并发处理能力。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `max_workers` | `MAX_WORKERS` | int | `4` | 否 | 最大工作线程数 |

**配置示例：**
```bash
# 高并发配置
MAX_WORKERS=8

# 低资源配置
MAX_WORKERS=2

# 单核系统
MAX_WORKERS=1
```

**性能建议：**
- CPU密集型：设置为CPU核心数
- I/O密集型：可设置为CPU核心数的2-4倍
- 内存受限：适当降低线程数

### 💾 会话持久化配置（4项）

控制对话会话的持久化存储和过期管理。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `session_persistence_enabled` | `SESSION_PERSISTENCE_ENABLED` | bool | `True` | 否 | 是否启用会话持久化 |
| `session_persistence_dir` | `SESSION_PERSISTENCE_DIR` | str | `./sessions` | 否 | 会话持久化存储目录 |
| `session_max_persistence_hours` | `SESSION_MAX_PERSISTENCE_HOURS` | int | `24` | 否 | 会话最大持久化时间（小时） |
| `session_cleanup_interval_minutes` | `SESSION_CLEANUP_INTERVAL_MINUTES` | int | `60` | 否 | 会话清理间隔（分钟） |

**配置示例：**
```bash
# 长期存储配置
SESSION_PERSISTENCE_ENABLED=true
SESSION_PERSISTENCE_DIR=/var/lib/ai-dialogue/sessions
SESSION_MAX_PERSISTENCE_HOURS=168  # 7天
SESSION_CLEANUP_INTERVAL_MINUTES=30

# 临时存储配置
SESSION_MAX_PERSISTENCE_HOURS=2    # 2小时
SESSION_CLEANUP_INTERVAL_MINUTES=10

# 禁用持久化
SESSION_PERSISTENCE_ENABLED=false
```

**持久化策略：**
- **短期对话（1-6小时）**：适合临时使用场景
- **日常对话（12-48小时）**：适合常规使用
- **长期对话（7-30天）**：适合重要项目讨论
- **永久存储**：需要额外的归档机制

## 环境配置文件

### .env 文件模板

开发环境推荐的完整 `.env` 配置：

```bash
# ==========================================
# AI对话应用后端 - 完整配置示例
# ==========================================

# OpenRouter LLM API 配置
# 获取密钥：https://openrouter.ai/keys
OPENROUTER_API_KEY=sk-or-v1-your-api-key-here
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_MODEL=anthropic/claude-3-haiku
OPENROUTER_TEMPERATURE=0.7
OPENROUTER_MAX_TOKENS=800

# STT 语音识别配置
# 引擎选择: mock, whisper, vosk
STT_ENGINE=whisper

# Whisper STT 配置
USE_WHISPER=true
WHISPER_MODEL_NAME=base
WHISPER_MODEL_PATH=model/whisper-models
WHISPER_DEVICE=auto
WHISPER_COMPUTE_TYPE=int8
WHISPER_BATCH_SIZE=16
WHISPER_BEAM_SIZE=5
WHISPER_LANGUAGE=null
WHISPER_VAD_FILTER=true
WHISPER_WORD_TIMESTAMPS=false
WHISPER_TEMPERATURE=0.0
WHISPER_CONDITION_ON_PREVIOUS_TEXT=true

# Vosk STT 配置（备用）
# 模型下载：https://alphacephei.com/vosk/models
USE_REAL_VOSK=false
VOSK_MODEL_PATH=model/vosk-model
VOSK_SAMPLE_RATE=16000

# 服务器网络配置
HOST=127.0.0.1
PORT=8000
DEBUG=true
ALLOWED_ORIGINS=["*"]

# 超时设置（秒）
STT_TIMEOUT=30
LLM_TIMEOUT=30
WEBSOCKET_TIMEOUT=600
WEBSOCKET_PING_INTERVAL=30
WEBSOCKET_PING_TIMEOUT=10
WEBSOCKET_MAX_MESSAGE_SIZE=16777216
TIMEOUT=60

# 日志记录配置
LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_FILE=logs/app.log
LOG_MAX_SIZE=100MB
LOG_BACKUP_COUNT=5

# 音频处理配置
AUDIO_CHUNK_SIZE=4096
AUDIO_SAMPLE_RATE=16000
AUDIO_CHANNELS=1
AUDIO_BUFFER_MAX_SIZE=52428800
AUDIO_BUFFER_CLEANUP_INTERVAL=10
AUDIO_MAX_CHUNKS_PER_SECOND=100

# 性能配置
MAX_WORKERS=4

# 会话持久化配置
SESSION_PERSISTENCE_ENABLED=true
SESSION_PERSISTENCE_DIR=./sessions
SESSION_MAX_PERSISTENCE_HOURS=24
SESSION_CLEANUP_INTERVAL_MINUTES=60
```

### 生产环境配置

生产环境推荐配置 `.env.production`：

```bash
# ==========================================  
# 生产环境配置
# ==========================================

# 安全性设置
DEBUG=false
LOG_LEVEL=INFO
LOG_FORMAT=json

# 网络配置
HOST=0.0.0.0
PORT=8000
ALLOWED_ORIGINS=["https://yourdomain.com"]

# API服务配置
STT_ENGINE=whisper
USE_WHISPER=true
WHISPER_MODEL_NAME=base
WHISPER_DEVICE=auto
WHISPER_COMPUTE_TYPE=int8
OPENROUTER_API_KEY=sk-or-v1-production-api-key
OPENROUTER_MODEL=anthropic/claude-3-sonnet
OPENROUTER_TEMPERATURE=0.5
OPENROUTER_MAX_TOKENS=1000

# 性能优化
STT_TIMEOUT=20
LLM_TIMEOUT=45
WEBSOCKET_TIMEOUT=600
WEBSOCKET_PING_INTERVAL=30
MAX_WORKERS=8

# 音频处理优化
AUDIO_CHUNK_SIZE=8192
VOSK_SAMPLE_RATE=16000
AUDIO_BUFFER_MAX_SIZE=104857600  # 100MB

# 会话管理
SESSION_MAX_PERSISTENCE_HOURS=72  # 3天
SESSION_CLEANUP_INTERVAL_MINUTES=30

# 日志配置
LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_FILE=/var/log/ai-dialogue/app.log
LOG_MAX_SIZE=500MB
LOG_BACKUP_COUNT=10
```

## 配置验证和测试

### 配置正确性检查

启动应用后，访问健康检查端点验证配置：

```bash
# 检查后端总体状态
curl http://localhost:8000/

# 检查对话服务状态  
curl http://localhost:8000/conversation/health
```

**期望响应：**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "services": {
    "stt": {
      "status": "healthy", 
      "mode": "whisper|vosk|mock",
      "engine": "whisper",
      "model_name": "base",
      "device": "cpu",
      "model_loaded": true
    },
    "llm": {
      "status": "healthy",
      "mode": "openrouter|mock", 
      "api_configured": true,
      "model": "anthropic/claude-3-haiku"
    },
    "session_manager": {
      "status": "healthy",
      "active_sessions": 0
    },
    "request_manager": {
      "status": "healthy", 
      "active_requests": 0
    }
  },
  "config": {
    "host": "127.0.0.1",
    "port": 8000,
    "debug": true,
    "log_level": "INFO"
  }
}
```

### 配置测试工具

**环境变量检查脚本：**

```python
# check_config.py
import os
from app.config.settings import settings

def check_config():
    print("🔧 配置检查报告")
    print("=" * 40)
    
    # OpenRouter配置
    if settings.openrouter_api_key:
        print("✅ OpenRouter: 真实模式")
        print(f"   模型: {settings.openrouter_model}")
    else:
        print("⚠️  OpenRouter: Mock模式")
    
    # STT配置
    print(f"🎙️  STT引擎: {settings.stt_engine}")
    if settings.stt_engine == "whisper":
        whisper_model_path = os.path.join(settings.whisper_model_path, f"{settings.whisper_model_name}-ct2")
        if os.path.exists(whisper_model_path):
            print("✅ Whisper: 真实模式")
            print(f"   模型: {settings.whisper_model_name}")
            print(f"   设备: {settings.whisper_device}")
        else:
            print("⚠️  Whisper: 模型文件不存在")
    elif settings.stt_engine == "vosk":
        if os.path.exists(settings.vosk_model_path):
            print("✅ Vosk: 真实模式")
        else:
            print("⚠️  Vosk: Mock模式（模型文件不存在）")
    else:
        print("⚠️  STT: Mock模式")
    
    # 网络配置
    print(f"🌐 服务地址: {settings.host}:{settings.port}")
    print(f"🐛 调试模式: {settings.debug}")
    print(f"📝 日志级别: {settings.log_level}")

if __name__ == "__main__":
    check_config()
```

运行检查：
```bash
python check_config.py
```

## 常见配置场景

### 场景1：开发环境（Mock模式）

快速开始，无需外部服务：

```bash
# 最小配置
DEBUG=true
LOG_LEVEL=DEBUG
```

所有服务使用Mock模式，适合前端开发和功能测试。

### 场景2：本地全功能测试

使用真实服务进行完整测试：

```bash
# 完整本地测试配置
OPENROUTER_API_KEY=sk-or-v1-your-test-key
STT_ENGINE=whisper
WHISPER_MODEL_NAME=base
DEBUG=true
LOG_LEVEL=DEBUG
```

### 场景3：生产部署

高性能、高可靠性配置：

```bash
# 生产环境配置
DEBUG=false
LOG_LEVEL=INFO
HOST=0.0.0.0
OPENROUTER_API_KEY=sk-or-v1-production-key
OPENROUTER_MODEL=anthropic/claude-3-sonnet
OPENROUTER_TEMPERATURE=0.3
STT_TIMEOUT=20
LLM_TIMEOUT=45
```

### 场景4：Docker容器部署

容器化部署的特殊配置：

```bash
# Docker专用配置
HOST=0.0.0.0
PORT=8000
STT_ENGINE=whisper
WHISPER_MODEL_PATH=/app/model/whisper-models
LOG_FORMAT=json
DEBUG=false
```

## 配置最佳实践

### 🔒 安全最佳实践

1. **敏感信息保护：**
   ```bash
   # 使用环境变量，不要写入代码
   export OPENROUTER_API_KEY=sk-or-v1-xxx
   
   # .env文件不要提交到版本控制
   echo ".env" >> .gitignore
   ```

2. **密钥轮换：**
   ```bash
   # 定期更新API密钥
   # 使用密钥管理服务（如AWS Secrets Manager）
   ```

### ⚡ 性能优化配置

1. **生产环境优化：**
   ```bash
   DEBUG=false
   LOG_LEVEL=INFO
   OPENROUTER_TEMPERATURE=0.3  # 更一致的输出
   STT_TIMEOUT=20  # 较短超时
   AUDIO_CHUNK_SIZE=8192  # 较大块减少处理频率
   ```

2. **开发环境优化：**
   ```bash
   DEBUG=true
   LOG_LEVEL=DEBUG
   OPENROUTER_TEMPERATURE=0.7  # 更有创意的输出
   STT_TIMEOUT=60  # 较长超时便于调试
   ```

### 🔄 配置版本管理

1. **多环境配置：**
   ```
   config/
   ├── .env.development
   ├── .env.testing  
   ├── .env.staging
   └── .env.production
   ```

2. **环境切换脚本：**
   ```bash
   #!/bin/bash
   # switch_env.sh
   ENV=${1:-development}
   cp config/.env.$ENV .env
   echo "Switched to $ENV environment"
   ```

### 📊 监控和调试配置

1. **调试模式配置：**
   ```bash
   LOG_LEVEL=DEBUG
   DEBUG=true
   STT_TIMEOUT=300  # 长超时便于调试
   LLM_TIMEOUT=300
   ```

2. **生产监控配置：**
   ```bash
   LOG_LEVEL=INFO
   LOG_FORMAT=json  # 便于日志分析
   DEBUG=false
   ```

## 故障排除

### 配置相关常见问题

1. **OpenRouter API调用失败：**
   ```bash
   # 检查密钥是否正确
   curl -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        https://openrouter.ai/api/v1/models
   
   # 检查模型名称是否存在
   # 查看支持的模型列表
   ```

2. **Whisper模型加载失败：**
   ```bash
   # 检查模型路径
   ls -la $WHISPER_MODEL_PATH/$WHISPER_MODEL_NAME-ct2/
   
   # 确保包含必要文件：config.json, model.bin等
   # 如果模型不存在，运行下载脚本
   python scripts/download_whisper_models.py --model base --verify
   ```

3. **Vosk模型加载失败：**
   ```bash
   # 检查模型路径
   ls -la $VOSK_MODEL_PATH/
   
   # 确保包含必要文件
   # am/ graph/ ivector/ conf/
   ```

4. **端口绑定失败：**
   ```bash
   # 检查端口占用
   lsof -i :$PORT
   
   # 更换端口
   export PORT=8001
   ```

5. **WebSocket连接问题：**
   ```bash
   # 检查防火墙设置
   # 确保HOST设置正确（容器中使用0.0.0.0）
   ```

### 配置验证清单

部署前检查清单：

- [ ] API密钥配置正确
- [ ] STT引擎正确选择（whisper/vosk/mock）
- [ ] Whisper模型文件已下载并转换
- [ ] Vosk模型文件存在且可访问（如使用）
- [ ] 端口未被占用
- [ ] 防火墙规则允许访问
- [ ] 日志级别适合环境
- [ ] 超时设置合理
- [ ] 音频参数匹配前端
- [ ] 健康检查通过

## 扩展配置

### 自定义配置项

如需添加新的配置项，请修改 `config/settings.py`：

```python
# 在Settings类中添加新字段
class Settings(BaseSettings):
    # 现有配置...
    
    # 新增配置项
    custom_feature_enabled: bool = Field(
        default=False, 
        description="自定义功能开关"
    )
    custom_api_url: str = Field(
        default="https://api.example.com",
        description="自定义API地址"
    )
```

然后更新环境变量：
```bash
CUSTOM_FEATURE_ENABLED=true
CUSTOM_API_URL=https://my-api.com
```

### 配置热重载

开发环境支持配置热重载：

```bash
# 使用uvicorn的自动重载功能
uvicorn app.main:app --reload --env-file .env
```

修改 `.env` 文件后应用会自动重启并加载新配置。

---

## 总结

本配置文档涵盖了AI对话应用后端的所有可配置项。请根据您的部署环境和需求选择合适的配置方案。

**记住：**
- 开发环境可以使用Mock模式快速开始
- 生产环境务必配置真实的API密钥
- 定期检查和更新配置以确保最佳性能
- 保护好敏感配置信息的安全性

如有配置相关问题，请参考健康检查端点的输出信息进行排查。