# AI对话应用后端部署指南

## 概述

本文档提供AI对话应用后端的完整部署指南，包括开发环境部署和生产环境Docker部署两种方式。

## 快速导航

- 📋 **[详细配置说明](CONFIGURATION.md)** - 所有配置项的完整说明
- 🚀 **[部署指南](#部署指南)** - 开发和生产环境部署
- 🔧 **[故障排除](#故障排除)** - 常见问题解决方案
- 🏗️ **[项目结构](#项目结构)** - 代码组织结构

## 系统要求

### 基础环境
- Python 3.12+ （推荐3.12，3.9版本存在依赖兼容性问题）
- Git
- 网络连接（用于下载依赖和模型）

### 可选组件
- Docker 和 Docker Compose（生产环境部署）
- Vosk语音识别模型（真实STT服务）
- OpenRouter API密钥（真实LLM服务）

### 📋 重要配置说明

本应用支持丰富的配置选项，详细配置说明请参考：**[CONFIGURATION.md](CONFIGURATION.md)**

**快速配置要点：**
- 🔑 **OpenRouter API**: 配置 `OPENROUTER_API_KEY` 启用真实LLM服务
- 🎙️ **语音识别**: 下载Vosk模型启用真实STT服务  
- 🌐 **网络设置**: 生产环境需设置 `HOST=0.0.0.0`
- 📝 **日志配置**: 可调整 `LOG_LEVEL` 和 `LOG_FORMAT`

## 项目结构

```
backend/
├── app/                    # 应用核心代码
│   ├── api/               # API路由
│   ├── models/            # 数据模型
│   ├── services/          # 核心服务
│   ├── websocket/         # WebSocket处理
│   └── main.py           # 应用入口
├── config/                # 配置管理
├── model/                 # AI模型存储
├── requirements.txt       # Python依赖
├── Dockerfile            # Docker镜像构建
├── docker-compose.yml    # Docker编排
└── README.md            # 本文档
```

---

## 方式一：开发环境部署

### 1. 环境准备

#### 1.1 克隆项目
```bash
git clone <your-repository-url>
cd 荣昶杯项目/backend
```

#### 1.2 创建Python虚拟环境

> ⚠️ **重要提醒**：本项目需要Python 3.12+。如果使用Python 3.9可能会遇到依赖兼容性问题。

```bash
# 确认Python版本（必须3.12+）
python --version

# 使用venv
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate     # Windows

# 使用conda/mamba（推荐）
mamba create -n rongchang python=3.9
mamba activate rongchang
```

#### 1.3 安装Python依赖
```bash
pip install -r requirements.txt
```

### 2. 配置设置

#### 2.1 环境变量配置
创建 `.env` 文件（基础配置示例）：
```bash
# OpenRouter LLM配置（可选）
OPENROUTER_API_KEY=your_api_key_here
OPENROUTER_MODEL=anthropic/claude-3-haiku
OPENROUTER_TEMPERATURE=0.7

# Vosk STT配置（可选）
VOSK_MODEL_PATH=model/vosk-model
VOSK_SAMPLE_RATE=16000

# 服务器配置
HOST=127.0.0.1
PORT=8000
DEBUG=true
LOG_LEVEL=INFO
```

> 💡 **完整配置说明**: 查看 [CONFIGURATION.md](CONFIGURATION.md) 了解所有52个配置项的详细说明、默认值和最佳实践。

#### 2.2 下载Vosk模型（推荐）
如果要使用真实的语音识别服务（推荐测试环境使用）：

> 💡 **提示**：模型目录结构已预创建，详细说明请查看 `backend/model/vosk-model/README.md`

```bash
# 进入模型目录
cd backend/model/vosk-model

# 下载中文模型（约500MB，推荐）
wget https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
unzip vosk-model-cn-0.22.zip
mv vosk-model-cn-0.22/* .
rm -rf vosk-model-cn-0.22 vosk-model-cn-0.22.zip

# 或下载小型英文模型（约50MB，快速测试）
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
mv vosk-model-small-en-us-0.15/* .
rm -rf vosk-model-small-en-us-0.15 vosk-model-small-en-us-0.15.zip

# 验证模型文件
ls -la  # 应该看到 am/, conf/, graph/, ivector/ 目录
```

> ⚠️ **重要**：如果不下载模型，应用将使用Mock STT服务（用于开发测试）

### 3. 启动服务

#### 3.1 开发模式启动
```bash
# 确保在backend目录下
cd /path/to/荣昶杯项目/backend

# 推荐方式：使用uvicorn直接启动
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 或使用Python模块启动（需要设置PYTHONPATH）
PYTHONPATH=. python -m app.main

# 最简单方式：直接运行main.py
python app/main.py
```

#### 3.2 验证部署
```bash
# 检查后端总体健康状态
curl http://localhost:8000/

# 检查对话服务健康状态
curl http://localhost:8000/conversation/health

# 预期响应（根健康检查）
{
  "status": "healthy",
  "timestamp": "2024-01-XX...",
  "service": "AI对话应用后端总服务",
  "version": "1.0.0",
  "description": "后端进程运行正常，各服务状态良好"
}

# 测试WebSocket连接
# 使用浏览器开发者工具或WebSocket客户端连接：
# ws://localhost:8000/conversation
```

#### 3.3 运行功能测试（推荐）
```bash
# 运行完整的功能验证测试套件
cd ../tests/backend
python run_all_tests.py

# 或单独运行特定测试
python test_audio_stream_fix.py      # 音频流处理测试
python test_response_count_fix.py    # response_count更新测试
```

> 📋 **测试详情**: 完整的测试说明请参考 [`../tests/backend/README.md`](../tests/backend/README.md)

### 4. 开发环境配置调优

#### 4.1 日志配置
```bash
# 开启详细日志
export LOG_LEVEL=DEBUG

# 或在代码中修改 config/settings.py
log_level: str = "DEBUG"
```

#### 4.2 热重载开发
```bash
# 使用uvicorn的自动重载功能
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

#### 4.3 调试配置
在IDE中配置调试：
- **启动脚本**: `app/main.py`  
- **工作目录**: `backend/`
- **环境变量**: 按需设置上述环境变量

---

## 方式二：Docker生产环境部署

### 1. 环境准备

#### 1.1 安装Docker
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose

# CentOS/RHEL
sudo yum install docker docker-compose

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker
```

#### 1.2 验证Docker安装
```bash
docker --version
docker-compose --version
```

### 2. 构建和部署

#### 2.1 使用docker-compose快速部署
```bash
# 克隆项目
git clone <your-repository-url>
cd 荣昶杯项目/backend

# 构建并启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f ai-backend
```

#### 2.2 手动Docker部署
```bash
# 构建镜像
docker build -t ai-dialogue-backend .

# 运行容器
docker run -d \
  --name ai-backend \
  -p 8000:8000 \
  -e OPENROUTER_API_KEY=your_api_key \
  -e LOG_LEVEL=INFO \
  -v $(pwd)/model:/app/model \
  ai-dialogue-backend

# 查看容器状态
docker ps
docker logs ai-backend
```

### 3. 生产环境配置

#### 3.1 环境变量配置
创建 `.env.production` 文件：
```bash
# 生产环境核心配置
DEBUG=false
LOG_LEVEL=INFO
LOG_FORMAT=json
HOST=0.0.0.0
PORT=8000

# OpenRouter生产配置
OPENROUTER_API_KEY=your_production_api_key
OPENROUTER_MODEL=anthropic/claude-3-sonnet
OPENROUTER_TEMPERATURE=0.3
OPENROUTER_MAX_TOKENS=1000

# Vosk STT配置
VOSK_MODEL_PATH=/app/model/vosk-model
VOSK_SAMPLE_RATE=16000

# 性能优化
STT_TIMEOUT=20
LLM_TIMEOUT=45
WEBSOCKET_TIMEOUT=600
```

> 📖 **详细配置指南**: [CONFIGURATION.md](CONFIGURATION.md) 包含完整的生产环境配置最佳实践。

#### 3.2 数据持久化
```bash
# 创建数据卷
docker volume create ai-backend-models
docker volume create ai-backend-logs

# 在docker-compose.yml中配置持久化
volumes:
  - ai-backend-models:/app/model
  - ai-backend-logs:/app/logs
```

#### 3.3 反向代理配置（Nginx）
```nginx
# /etc/nginx/sites-available/ai-backend
server {
    listen 80;
    server_name your-api-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket特殊配置
    location /ws/ {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

### 4. 生产环境优化

#### 4.1 性能配置
```bash
# 在docker-compose.yml中设置资源限制
services:
  ai-backend:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          memory: 2G
```

#### 4.2 健康检查
```bash
# 在Dockerfile中添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8000/api/health || exit 1
```

#### 4.3 日志管理
```bash
# 配置日志轮转
# 在docker-compose.yml中
logging:
  driver: "json-file"
  options:
    max-size: "100m"
    max-file: "5"
```

---

## 前端集成指南

### WebSocket 连接和对话开启

**连接地址：** `ws://localhost:8000/conversation`

**前端集成示例：**
```javascript
// 连接到对话服务WebSocket端点
const ws = new WebSocket('ws://localhost:8000/conversation');

ws.onopen = function() {
  console.log('WebSocket连接已建立');
  
  // 发送开启对话请求
  ws.send(JSON.stringify({
    type: "conversation_start",
    data: {
      scenario_description: "商务会议讨论", // 可选
      response_count: 3 // 必需，1-5之间的整数
    }
  }));
};

ws.onmessage = function(event) {
  const response = JSON.parse(event.data);
  console.log('收到消息:', response);
  
  switch(response.type) {
    case 'session_created':
      // 保存会话ID，后续所有请求都需要这个ID
      const sessionId = response.data.session_id;
      console.log('会话创建成功，ID:', sessionId);
      break;
      
    case 'message_recorded':
      console.log('消息记录成功:', response.data.content);
      break;
      
    case 'opinion_suggestions':
      console.log('意见建议:', response.data.suggestions);
      break;
      
    case 'llm_response':
      console.log('AI回答建议:', response.data.suggestions);
      break;
      
    case 'error':
      console.error('错误:', response.data.message);
      break;
  }
};

ws.onerror = function(error) {
  console.error('WebSocket错误:', error);
};

ws.onclose = function(event) {
  console.log('WebSocket连接已关闭:', event.code, event.reason);
};
```

### API 端点

#### 健康检查端点
- **后端总健康检查**：`GET http://localhost:8000/`
  - 用途：简单的进程存活检查，快速响应
  - 适用于：负载均衡器 health check、监控系统
  - 响应示例：
    ```json
    {
      "status": "healthy",
      "timestamp": "2024-XX-XX...",
      "service": "AI对话应用后端总服务",
      "version": "1.0.0",
      "description": "后端进程运行正常，各服务状态良好"
    }
    ```
  
- **对话服务健康检查**：`GET http://localhost:8000/conversation/health`
  - 用途：深度检查对话相关服务状态（STT、LLM、会话管理等）
  - 适用于：服务诊断、故障排查
  - 响应示例：
    ```json
    {
      "status": "healthy|degraded",
      "timestamp": 1705234567.89,
      "service": "对话服务",
      "version": "1.0.0", 
      "services": {
        "session_manager": "healthy",
        "stt_service": "healthy",
        "llm_service": "healthy",
        "request_manager": "healthy",
        "websocket_handler": "healthy"
      }
    }
    ```

#### WebSocket 端点
- **对话服务连接**：`ws://localhost:8000/conversation`
  - 用途：实时语音对话和消息交互
  - 连接后自动分配客户端ID
  - 支持所有定义的WebSocket事件类型

---

## 故障排除

### 常见问题

#### 1. 端口冲突
```bash
# 检查端口占用
lsof -i :8000
netstat -tulpn | grep 8000

# 解决方案：更改端口或停止冲突服务
export PORT=8001
```

#### 2. Python版本兼容性问题
```bash
# 检查当前Python版本
python --version

# 如果版本低于3.12，请升级Python
# Ubuntu/Debian
sudo apt update && sudo apt install python3.12 python3.12-venv python3.12-dev

# macOS (使用Homebrew)
brew install python@3.12

# 创建新的虚拟环境
python3.12 -m venv venv
source venv/bin/activate
```

#### 3. 依赖安装失败
```bash
# 更新pip
pip install --upgrade pip

# 使用国内镜像源
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple/
```

#### 4. Vosk模型加载失败
```bash
# 检查模型文件
ls -la model/vosk-model/

# 确保模型目录结构正确
model/vosk-model/
├── am/
├── graph/
├── ivector/
└── conf/

# 权限问题
chmod -R 755 model/
```

#### 5. 模块导入错误 (Could not import module "main")
```bash
# 错误现象：Error loading ASGI app. Could not import module "main"

# 解决方案1：使用正确的启动命令（推荐）
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 解决方案2：设置PYTHONPATH环境变量
export PYTHONPATH=.
python -m app.main

# 解决方案3：直接运行main.py
python app/main.py

# 确认工作目录正确（应在backend目录下）
pwd  # 应显示 */荣昶杯项目/backend
ls -la app/  # 应能看到main.py文件
```

#### 6. 音频流处理错误
```bash
# 错误现象：前端发送音频流时报错"会话的音频流未开始"
# ✅ 已修复 (v1.2.1)：message_start事件现在会自动启动音频流处理

# 验证修复：运行音频流测试
cd ../tests/backend
python test_audio_stream_fix.py

# 如果仍有问题，检查STT服务状态
curl http://localhost:8000/conversation/health
```

#### 7. LLM回答数量不响应更新
```bash
# 错误现象：发送response_count_update后，manual_generate仍返回固定数量
# ✅ 已修复 (v1.2.1)：LLM现在能正确响应前端的数量设置

# 验证修复：运行回答数量测试
cd ../tests/backend
python test_response_count_fix.py

# 测试不同数量：应该看到2个→3个→5个建议的正确变化
```

#### 8. WebSocket连接失败
```bash
# 检查防火墙设置
sudo ufw allow 8000
sudo firewall-cmd --permanent --add-port=8000/tcp

# 检查代理配置
# 确保WebSocket升级头正确设置

# 确认WebSocket端点正确
# 正确地址：ws://localhost:8000/conversation
```

#### 9. Docker容器启动失败
```bash
# 查看详细错误信息
docker-compose logs ai-backend

# 检查镜像构建
docker build --no-cache -t ai-dialogue-backend .

# 检查容器内部
docker exec -it ai-backend /bin/bash
```

### 日志调试

#### 查看实时日志
```bash
# 开发环境
tail -f logs/app.log

# Docker环境
docker-compose logs -f ai-backend

# 筛选特定级别日志
docker-compose logs ai-backend | grep ERROR
```

#### 性能监控
```bash
# 系统资源使用
htop
docker stats

# 应用性能
curl http://localhost:8000/api/health
```

---

## 安全注意事项

### 1. API密钥管理
- 不要将API密钥提交到版本控制
- 使用环境变量或密钥管理服务
- 定期轮换API密钥

### 2. 网络安全
- 在生产环境中配置防火墙
- 使用HTTPS和WSS协议
- 限制跨域访问

### 3. 容器安全
- 定期更新基础镜像
- 以非root用户运行容器
- 扫描镜像安全漏洞

---

## 扩展和维护

### 升级部署
```bash
# 开发环境升级
git pull origin main
pip install -r requirements.txt --upgrade

# Docker环境升级
docker-compose down
docker-compose pull
docker-compose up -d
```

### 备份和恢复
```bash
# 备份配置和模型
tar -czf backup-$(date +%Y%m%d).tar.gz model/ config/ .env

# 恢复
tar -xzf backup-20240101.tar.gz
```

### 监控和告警
- 配置应用性能监控（APM）
- 设置日志告警规则
- 监控资源使用情况

---

## 技术支持

如有问题，请检查：
1. 项目文档：`docs/`
2. 应用日志：`logs/` 或 `docker-compose logs`
3. 健康检查：`http://localhost:8000/api/health`

如需进一步协助，请提供：
- 错误日志信息
- 系统环境信息
- 配置文件内容（隐藏敏感信息）