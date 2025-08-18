# AI对话应用后端部署指南

## 概述

本文档提供AI对话应用后端的完整部署指南，包括开发环境部署和生产环境Docker部署两种方式。

## 快速导航

- 📋 **[详细配置说明](CONFIGURATION.md)** - 所有配置项的完整说明
- 🚀 **[部署指南](#部署指南)** - 开发和生产环境部署
- 🐳 **[Docker部署](#docker部署)** - 容器化生产环境部署（推荐）
- 🔧 **[故障排除](#故障排除)** - 常见问题解决方案
- 🏗️ **[项目结构](#项目结构)** - 代码组织结构

## 系统要求

### 基础环境
- **开发环境**: Python 3.12+ （推荐3.12，3.9+可用）
- **生产环境**: Docker 20.0+ + Docker Compose 2.0+
- Git
- 网络连接（用于下载依赖和模型）

### 可选组件
- Vosk语音识别模型（真实STT服务）
- OpenRouter API密钥（真实LLM服务）
- Nginx（反向代理，生产环境推荐）

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
├── Dockerfile            # Docker镜像构建配置
├── docker-compose.yml    # Docker Compose服务编排
├── deploy-docker.sh      # Docker部署脚本
├── .env.example         # 环境变量示例
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

> ⚠️ **重要提醒**：本项目需要Python 3.9+，推荐使用Python 3.12。

```bash
# 确认Python版本（必须3.9+）
python --version

# 使用venv
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate     # Windows

# 使用conda/mamba（推荐）
mamba create -n rongchang python=3.12
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

> 💡 **完整配置说明**: 查看 [CONFIGURATION.md](CONFIGURATION.md) 了解所有配置项的详细说明、默认值和最佳实践。

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

## 方式二：Docker部署（推荐生产环境）

### 1. 快速部署

使用提供的部署脚本，一键部署容器化服务：

```bash
# 给脚本执行权限
chmod +x deploy-docker.sh

# 一键部署（自动启用加速优化）
./deploy-docker.sh

# 或者手动使用 Docker Compose
export DOCKER_BUILDKIT=1  # 启用BuildKit
docker compose up -d --build
```

**🚀 性能优化特性：**
- ✅ **apt镜像加速**: 使用阿里云镜像源
- ✅ **pip镜像加速**: 使用清华大学镜像源  
- ✅ **uv包管理器**: 比pip快10-100倍的Python包安装
- ✅ **BuildKit缓存**: 智能层缓存，大幅减少重复构建时间
- ✅ **多阶段构建**: 最小化最终镜像体积
- ✅ **缓存挂载**: 依赖安装缓存持久化

### 2. 环境配置

#### 2.1 配置优先级说明

🎯 **重要特性：支持灵活的环境配置方式**

**配置优先级（从高到低）：**
1. **`.env` 文件**：如果backend目录下存在.env文件，优先使用其中的配置
2. **docker-compose.yml默认值**：作为后备配置，确保服务正常启动

**使用场景：**
- **开发环境**：无.env文件，使用docker-compose.yml中的默认值
- **生产环境**：创建.env文件，覆盖需要自定义的配置项

#### 2.2 环境变量设置

**生产环境配置（推荐）：**
```bash
# 复制Docker环境变量示例文件
cp .env.docker.example .env

# 编辑环境变量配置
nano .env
```

**.env文件配置示例：**
```bash
# LLM服务配置
OPENROUTER_API_KEY=sk-or-v1-your-actual-api-key-here
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_MODEL=qwen/qwen3-235b-a22b:free

# STT服务配置
USE_REAL_VOSK=true
VOSK_MODEL_PATH=/app/model/vosk-model

# 安全配置
ALLOWED_ORIGINS=["https://yourdomain.com"]

# 基础配置
DEBUG=false
LOG_LEVEL=INFO
```

**开发环境（无需创建.env文件）：**
如果不创建.env文件，系统会自动使用docker-compose.yml中的默认配置，适合开发和测试环境。

#### 2.3 模型文件配置（可选）
如果使用Vosk语音识别：
```bash
# 创建模型目录
mkdir -p model/vosk-model

# 下载中文模型
cd model/vosk-model
wget https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
unzip vosk-model-cn-0.22.zip
mv vosk-model-cn-0.22/* .
rm -rf vosk-model-cn-0.22*

# 验证模型结构
ls -la  # 应该看到 am/, conf/, graph/, ivector/ 目录
```

### 3. 容器管理

#### 3.1 基本操作
```bash
# 启动服务
./deploy-docker.sh
# 或
docker compose up -d

# 停止服务
./deploy-docker.sh --stop
# 或
docker compose down

# 重启服务
./deploy-docker.sh --restart
# 或
docker compose restart

# 查看服务状态
./deploy-docker.sh --status
# 或
docker compose ps
```

#### 3.2 日志查看
```bash
# 查看实时日志
./deploy-docker.sh --logs
# 或
docker compose logs -f

# 查看容器状态
docker compose ps

# 查看最近日志
docker compose logs --tail=50
```

#### 3.3 强制重新构建
```bash
# 强制重建镜像（使用优化构建）
./deploy-docker.sh --build --no-cache

# 使用多阶段构建（进一步优化镜像大小）
docker build -f Dockerfile.multi-stage -t ai-dialogue-backend .

# 或手动操作
docker compose down
docker compose build --no-cache
docker compose up -d
```

**⚡ 构建性能对比：**
| 方式 | 首次构建时间 | 重新构建时间 | 镜像大小 |
|------|-------------|-------------|----------|
| 传统pip | ~8-12分钟 | ~5-8分钟 | ~800MB |
| uv + 镜像加速 | ~2-4分钟 | ~30秒-2分钟 | ~600MB |
| 多阶段构建 | ~3-5分钟 | ~1-3分钟 | ~400MB |

### 4. 服务监控

#### 4.1 健康检查
```bash
# 手动健康检查
curl http://localhost:8000/
curl http://localhost:8000/conversation/health

# 查看容器健康状态
docker compose ps
```

#### 4.2 性能监控
```bash
# 查看容器资源使用
docker stats

# 查看容器详细信息
docker compose exec ai-dialogue-backend ps aux

# 查看端口映射
docker compose port ai-dialogue-backend 8000
```

### 5. 生产环境配置

#### 5.1 Nginx反向代理
```nginx
# /etc/nginx/sites-available/ai-dialogue-backend
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket支持
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

#### 5.2 SSL/TLS配置
```bash
# 使用 Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 6. 数据持久化

#### 6.1 日志持久化
```yaml
# docker-compose.yml 中已配置
volumes:
  - ./logs:/app/logs        # 日志目录映射到主机
  - ./model:/app/model:ro   # 模型目录只读映射
```

#### 6.2 备份和恢复
```bash
# 备份配置和日志
tar -czf backup-$(date +%Y%m%d).tar.gz \
    .env docker-compose.yml Dockerfile \
    logs/ model/

# 恢复
tar -xzf backup-20240101.tar.gz
docker compose up -d
```

### 7. 多环境部署

#### 7.1 开发环境
```bash
# 使用开发配置
cp .env.example .env.dev
# 编辑 .env.dev 设置 DEBUG=true
docker compose -f docker-compose.yml --env-file .env.dev up -d
```

#### 7.2 生产环境
```bash
# 使用生产配置
cp .env.example .env.prod
# 编辑 .env.prod 设置生产参数
docker compose -f docker-compose.yml --env-file .env.prod up -d
```

### 8. 故障排除

#### 8.1 容器无法启动
```bash
# 查看构建日志
docker compose build --no-cache

# 查看启动日志
docker compose logs ai-dialogue-backend

# 进入容器调试
docker compose exec ai-dialogue-backend bash
```

#### 8.2 网络连接问题
```bash
# 检查端口映射
docker compose ps
docker port ai-dialogue-backend

# 检查容器网络
docker network ls
docker network inspect backend_ai-dialogue-network
```

### 9. 升级和维护

#### 9.1 应用升级
```bash
# 拉取最新代码
git pull origin main

# 重新构建并部署
./deploy-docker.sh --build

# 或手动操作
docker compose down
docker compose build
docker compose up -d
```

#### 9.2 清理资源
```bash
# 清理未使用的镜像和容器
./deploy-docker.sh --clean

# 或手动清理
docker system prune -f
docker volume prune -f
```


---

## 故障排除

### 常见问题

#### 1. 端口冲突
```bash
# 检查端口占用
sudo lsof -i :8000
sudo netstat -tulpn | grep 8000

# 解决方案：更改端口或停止冲突服务
export PORT=8001
```

#### 2. Python版本兼容性问题
```bash
# 检查当前Python版本
python --version

# 如果版本低于3.9，请升级Python
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

#### 6. Docker服务问题

**容器启动失败：**
```bash
# 查看详细错误信息
docker compose logs ai-dialogue-backend

# 检查容器状态
docker compose ps

# 查看镜像构建日志
docker compose build --no-cache

# 进入容器调试
docker compose exec ai-dialogue-backend bash
```

**权限问题：**
```bash
# 检查文件权限
ls -la logs/
ls -la model/

# 修复权限
chmod -R 755 logs/
chmod -R 755 model/
```

**环境变量问题：**
```bash
# 检查环境变量文件
cat .env

# 查看容器中的环境变量
docker compose exec ai-dialogue-backend env | grep -E "(OPENROUTER|VOSK|LOG)"

# 测试手动启动
docker compose exec ai-dialogue-backend python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

#### 7. 网络连接问题
```bash
# 检查防火墙设置
sudo ufw allow 8000
sudo firewall-cmd --permanent --add-port=8000/tcp

# 检查容器端口映射
docker compose ps
docker compose port ai-dialogue-backend 8000

# 确认服务监听正确的地址
sudo netstat -tlnp | grep :8000
# 应该显示 0.0.0.0:8000 而不是 127.0.0.1:8000
```

### 日志调试

#### 查看实时日志
```bash
# Docker容器日志
docker compose logs -f ai-dialogue-backend

# 应用日志文件
tail -f logs/app.log

# 筛选特定级别日志
docker compose logs ai-dialogue-backend | grep ERROR
```

#### 性能监控
```bash
# 容器资源使用
docker stats ai-dialogue-backend

# 容器内进程
docker compose exec ai-dialogue-backend ps aux

# 容器状态
docker compose ps

# 网络连接
sudo ss -tlnp | grep :8000
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

### 3. 系统安全
- 定期更新系统和依赖
- 使用专用用户运行服务
- 配置适当的文件权限

### 4. 服务安全
- 启用SystemD安全特性
- 限制资源使用
- 配置日志轮转

---

## 扩展和维护

### 升级部署
```bash
# 开发环境升级
git pull origin main
pip install -r requirements.txt --upgrade

# 生产环境升级
cd /opt/ai-dialogue-backend
sudo -u backend git pull origin main
sudo -u backend ./venv/bin/pip install -r requirements.txt --upgrade
sudo systemctl restart ai-dialogue-backend
```

### 备份和恢复
```bash
# 备份配置和模型
sudo tar -czf backup-$(date +%Y%m%d).tar.gz \
    /opt/ai-dialogue-backend/config/ \
    /opt/ai-dialogue-backend/model/ \
    /etc/systemd/system/ai-dialogue-backend.service

# 恢复
sudo tar -xzf backup-20240101.tar.gz -C /
sudo systemctl daemon-reload
sudo systemctl restart ai-dialogue-backend
```

### 监控和告警
- 配置应用性能监控（APM）
- 设置日志告警规则
- 监控资源使用情况
- 配置健康检查脚本

---

## 技术支持

如有问题，请检查：
1. 项目文档：`docs/`
2. 应用日志：`/var/log/ai-dialogue-backend/` 或 `sudo journalctl -u ai-dialogue-backend`
3. 健康检查：`http://localhost:8000/`

如需进一步协助，请提供：
- 错误日志信息
- 系统环境信息
- 配置文件内容（隐藏敏感信息）

**常用命令总结：**

**开发环境：**
```bash
# 启动开发服务
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 健康检查
curl http://localhost:8000/
```

**Docker部署：**
```bash
# 一键部署
./deploy-docker.sh

# 容器管理
docker compose {up -d|down|restart|ps}

# 日志查看  
docker compose logs -f ai-dialogue-backend

# 健康检查
curl http://localhost:8000/

# 重新构建
./deploy-docker.sh --build --no-cache

# 停止服务
./deploy-docker.sh --stop
```