# AI对话应用后端 - 详细配置说明

## 配置概述

本文档详细说明了AI对话应用后端的所有可配置项，包括环境变量、配置文件选项、默认值和最佳实践建议。

## 配置方式

配置系统基于 Pydantic Settings，支持多种配置方式：

1. **环境变量** - 推荐生产环境使用
2. **`.env` 文件** - 推荐开发环境使用  
3. **代码默认值** - 系统内置默认值

优先级：环境变量 > .env文件 > 代码默认值

## 完整配置清单

### 🔗 OpenRouter LLM API 配置

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

### 🎙️ Vosk STT 语音识别配置

用于集成 Vosk 本地语音转文字服务。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `vosk_model_path` | `VOSK_MODEL_PATH` | str | `model/vosk-model` | 否 | Vosk模型文件路径 |
| `vosk_sample_rate` | `VOSK_SAMPLE_RATE` | int | `16000` | 否 | 音频采样率（Hz） |

**配置示例：**
```bash
# 使用中文模型
VOSK_MODEL_PATH=model/vosk-model-cn-0.22

# 使用英文模型  
VOSK_MODEL_PATH=model/vosk-model-small-en-us-0.15

# 高质量音频
VOSK_SAMPLE_RATE=44100
```

**模型下载建议：**
- 中文识别：`vosk-model-cn-0.22` (~500MB)
- 英文识别：`vosk-model-en-us-0.22` (~1.8GB)
- 小型英文：`vosk-model-small-en-us-0.15` (~40MB)

### 🌐 服务器网络配置

控制 FastAPI 应用的网络监听和访问设置。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `host` | `HOST` | str | `127.0.0.1` | 否 | 服务器监听地址 |
| `port` | `PORT` | int | `8000` | 否 | 服务器监听端口 |
| `debug` | `DEBUG` | bool | `True` | 否 | 调试模式开关 |

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

### ⏱️ 超时设置

控制各种服务操作的超时时间，防止长时间阻塞。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `stt_timeout` | `STT_TIMEOUT` | int | `30` | 否 | STT服务超时时间（秒） |
| `llm_timeout` | `LLM_TIMEOUT` | int | `30` | 否 | LLM服务超时时间（秒） |
| `websocket_timeout` | `WEBSOCKET_TIMEOUT` | int | `300` | 否 | WebSocket连接超时（秒） |

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

### 📝 日志记录配置

控制应用日志的输出级别和格式。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `log_level` | `LOG_LEVEL` | str | `INFO` | 否 | 日志级别 |
| `log_format` | `LOG_FORMAT` | str | `json` | 否 | 日志输出格式 |

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

### 🎵 音频处理配置

控制音频数据的处理参数。

| 配置项 | 环境变量 | 类型 | 默认值 | 必需 | 说明 |
|--------|----------|------|--------|------|------|
| `audio_chunk_size` | `AUDIO_CHUNK_SIZE` | int | `4096` | 否 | 音频数据块大小（字节） |
| `audio_sample_rate` | `AUDIO_SAMPLE_RATE` | int | `16000` | 否 | 音频采样率（Hz） |
| `audio_channels` | `AUDIO_CHANNELS` | int | `1` | 否 | 音频声道数 |

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

# Vosk STT 语音识别配置
# 模型下载：https://alphacephei.com/vosk/models
VOSK_MODEL_PATH=model/vosk-model
VOSK_SAMPLE_RATE=16000

# 服务器网络配置
HOST=127.0.0.1
PORT=8000
DEBUG=true

# 超时设置（秒）
STT_TIMEOUT=30
LLM_TIMEOUT=30
WEBSOCKET_TIMEOUT=300

# 日志记录配置
LOG_LEVEL=INFO
LOG_FORMAT=json

# 音频处理配置
AUDIO_CHUNK_SIZE=4096
AUDIO_SAMPLE_RATE=16000
AUDIO_CHANNELS=1
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

# API服务配置
OPENROUTER_API_KEY=sk-or-v1-production-api-key
OPENROUTER_MODEL=anthropic/claude-3-sonnet
OPENROUTER_TEMPERATURE=0.5
OPENROUTER_MAX_TOKENS=1000

# 性能优化
STT_TIMEOUT=20
LLM_TIMEOUT=45
WEBSOCKET_TIMEOUT=600

# 音频处理优化
AUDIO_CHUNK_SIZE=8192
VOSK_SAMPLE_RATE=16000
```

## 配置验证和测试

### 配置正确性检查

启动应用后，访问健康检查端点验证配置：

```bash
curl http://localhost:8000/api/health
```

**期望响应：**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "services": {
    "stt": {
      "status": "healthy", 
      "mode": "vosk|mock",
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
    
    # Vosk配置  
    if os.path.exists(settings.vosk_model_path):
        print("✅ Vosk: 真实模式")
    else:
        print("⚠️  Vosk: Mock模式（模型文件不存在）")
    
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
VOSK_MODEL_PATH=model/vosk-model-small-en-us-0.15
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
VOSK_MODEL_PATH=/app/model/vosk-model
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

2. **Vosk模型加载失败：**
   ```bash
   # 检查模型路径
   ls -la $VOSK_MODEL_PATH/
   
   # 确保包含必要文件
   # am/ graph/ ivector/ conf/
   ```

3. **端口绑定失败：**
   ```bash
   # 检查端口占用
   lsof -i :$PORT
   
   # 更换端口
   export PORT=8001
   ```

4. **WebSocket连接问题：**
   ```bash
   # 检查防火墙设置
   # 确保HOST设置正确（容器中使用0.0.0.0）
   ```

### 配置验证清单

部署前检查清单：

- [ ] API密钥配置正确
- [ ] 模型文件存在且可访问  
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