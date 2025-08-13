# AI对话应用后端部署指南

## 概述

本文档提供AI对话应用后端的完整部署指南，包括开发环境部署和生产环境Docker部署两种方式。

## 系统要求

### 基础环境
- Python 3.9+
- Git
- 网络连接（用于下载依赖和模型）

### 可选组件
- Docker 和 Docker Compose（生产环境部署）
- Vosk语音识别模型（真实STT服务）
- OpenRouter API密钥（真实LLM服务）

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
```bash
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
创建 `.env` 文件（可选）：
```bash
# OpenRouter LLM服务配置（可选）
OPENROUTER_API_KEY=your_api_key_here
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# Vosk STT服务配置（可选）
VOSK_MODEL_PATH=model/vosk-model
VOSK_SAMPLE_RATE=16000
USE_REAL_VOSK=false

# 应用配置
HOST=0.0.0.0
PORT=8000
DEBUG=true
LOG_LEVEL=INFO
```

#### 2.2 下载Vosk模型（可选）
如果要使用真实的语音识别服务：
```bash
# 创建模型目录
mkdir -p model

# 下载中文模型（约500MB）
cd model
wget https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
unzip vosk-model-cn-0.22.zip
mv vosk-model-cn-0.22 vosk-model

# 或下载小型英文模型（约50MB）
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
mv vosk-model-small-en-us-0.15 vosk-model
```

### 3. 启动服务

#### 3.1 开发模式启动
```bash
# 确保在backend目录下
cd /path/to/荣昶杯项目/backend

# 启动应用
python -m app.main

# 或使用uvicorn直接启动
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### 3.2 验证部署
```bash
# 检查健康状态
curl http://localhost:8000/api/health

# 预期响应
{
  "status": "healthy",
  "timestamp": "2024-01-XX...",
  "services": {
    "stt": "healthy",
    "llm": "healthy", 
    "session_manager": "healthy",
    "request_manager": "healthy"
  }
}

# 测试WebSocket连接
# 使用浏览器开发者工具或WebSocket客户端连接：
# ws://localhost:8000/ws/test_client_id
```

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
# 生产环境配置
DEBUG=false
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000

# LLM服务配置
OPENROUTER_API_KEY=your_production_api_key
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# STT服务配置
USE_REAL_VOSK=true
VOSK_MODEL_PATH=/app/model/vosk-model
VOSK_SAMPLE_RATE=16000

# 安全配置
ALLOWED_ORIGINS=["https://your-frontend-domain.com"]
```

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

#### 2. 依赖安装失败
```bash
# 更新pip
pip install --upgrade pip

# 使用国内镜像源
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple/
```

#### 3. Vosk模型加载失败
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

#### 4. WebSocket连接失败
```bash
# 检查防火墙设置
sudo ufw allow 8000
sudo firewall-cmd --permanent --add-port=8000/tcp

# 检查代理配置
# 确保WebSocket升级头正确设置
```

#### 5. Docker容器启动失败
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