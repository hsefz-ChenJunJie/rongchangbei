# AI对话应用后端部署指南

## 概述

本文档提供AI对话应用后端的完整部署指南，包括开发环境部署和生产环境SystemD服务部署两种方式。

## 快速导航

- 📋 **[详细配置说明](CONFIGURATION.md)** - 所有配置项的完整说明
- 🚀 **[部署指南](#部署指南)** - 开发和生产环境部署
- 🔧 **[故障排除](#故障排除)** - 常见问题解决方案
- 🏗️ **[项目结构](#项目结构)** - 代码组织结构
- ⚙️ **[SystemD服务](#systemd服务部署)** - 生产环境系统服务部署

## 系统要求

### 基础环境
- Python 3.12+ （推荐3.12，3.9+可用）
- Git
- 网络连接（用于下载依赖和模型）
- Linux系统（支持SystemD）

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
├── ai-dialogue-backend.service  # SystemD服务配置
├── install-service.sh     # 自动安装脚本
└── README.md             # 本文档
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

## 方式二：SystemD服务部署

### 1. 自动安装（推荐）

使用提供的自动安装脚本，一键部署生产环境：

```bash
# 给脚本执行权限
chmod +x install-service.sh

# 自动安装服务
sudo ./install-service.sh

# 或指定自定义参数
sudo ./install-service.sh --user myuser --dir /opt/myapp
```

安装脚本会自动完成以下步骤：
1. 创建服务用户和组
2. 创建必要目录结构
3. 复制项目文件到生产目录
4. 安装Python依赖
5. 配置SystemD服务
6. 启动并验证服务

### 2. 手动安装

如果需要手动控制安装过程：

#### 2.1 创建服务用户
```bash
# 创建专用用户和组
sudo groupadd --system backend
sudo useradd --system --gid backend --create-home \
    --home-dir /opt/ai-dialogue-backend --shell /bin/bash \
    --comment "AI Dialogue Backend Service" backend
```

#### 2.2 准备部署目录
```bash
# 创建应用目录
sudo mkdir -p /opt/ai-dialogue-backend
sudo mkdir -p /var/log/ai-dialogue-backend

# 复制项目文件
sudo cp -r app/ config/ requirements.txt /opt/ai-dialogue-backend/
sudo cp -r model/ /opt/ai-dialogue-backend/ # 如果有模型文件

# 设置权限
sudo chown -R backend:backend /opt/ai-dialogue-backend
sudo chown -R backend:backend /var/log/ai-dialogue-backend
```

#### 2.3 安装Python依赖
```bash
# 切换到服务用户
sudo -u backend bash

# 创建虚拟环境
cd /opt/ai-dialogue-backend
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt

# 退出服务用户会话
exit
```

#### 2.4 配置SystemD服务
```bash
# 复制服务配置文件
sudo cp ai-dialogue-backend.service /etc/systemd/system/

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用服务（开机自启动）
sudo systemctl enable ai-dialogue-backend

# 启动服务
sudo systemctl start ai-dialogue-backend
```

### 3. 服务管理

#### 3.1 基本操作
```bash
# 启动服务
sudo systemctl start ai-dialogue-backend

# 停止服务
sudo systemctl stop ai-dialogue-backend

# 重启服务
sudo systemctl restart ai-dialogue-backend

# 重新加载配置（无需重启）
sudo systemctl reload ai-dialogue-backend

# 查看服务状态
sudo systemctl status ai-dialogue-backend

# 查看服务是否开机自启动
sudo systemctl is-enabled ai-dialogue-backend
```

#### 3.2 日志查看
```bash
# 查看服务日志（实时）
sudo journalctl -u ai-dialogue-backend -f

# 查看最近的日志
sudo journalctl -u ai-dialogue-backend -n 50

# 查看今天的日志
sudo journalctl -u ai-dialogue-backend --since today

# 查看应用日志文件
sudo tail -f /var/log/ai-dialogue-backend/app.log
```

#### 3.3 配置修改
```bash
# 编辑服务配置
sudo systemctl edit ai-dialogue-backend

# 或直接编辑服务文件
sudo nano /etc/systemd/system/ai-dialogue-backend.service

# 修改后重新加载
sudo systemctl daemon-reload
sudo systemctl restart ai-dialogue-backend
```

### 4. 环境变量配置

在生产环境中，您需要配置实际的API密钥和其他设置。编辑服务文件：

```bash
sudo nano /etc/systemd/system/ai-dialogue-backend.service
```

修改Environment配置：
```ini
# 修改这些配置为您的实际值
Environment=OPENROUTER_API_KEY=your_actual_api_key_here
Environment=OPENROUTER_MODEL=anthropic/claude-3-sonnet
Environment=DEBUG=false
Environment=LOG_LEVEL=INFO
```

然后重新加载并重启服务：
```bash
sudo systemctl daemon-reload
sudo systemctl restart ai-dialogue-backend
```

### 5. 反向代理配置（可选）

#### 5.1 Nginx配置
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

启用配置：
```bash
sudo ln -s /etc/nginx/sites-available/ai-dialogue-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. 服务监控

#### 6.1 健康检查
```bash
# 手动健康检查
curl http://localhost:8000/
curl http://localhost:8000/conversation/health

# 设置定时健康检查
echo "*/5 * * * * curl -f http://localhost:8000/ || systemctl restart ai-dialogue-backend" | sudo crontab -
```

#### 6.2 性能监控
```bash
# 查看资源使用
sudo systemctl status ai-dialogue-backend
ps aux | grep python

# 查看端口监听
sudo netstat -tlnp | grep :8000

# 查看进程树
sudo systemctl status ai-dialogue-backend --full
```

### 7. 卸载服务

如果需要完全移除服务：

```bash
# 使用自动卸载脚本
sudo ./install-service.sh --uninstall

# 或手动卸载
sudo systemctl stop ai-dialogue-backend
sudo systemctl disable ai-dialogue-backend
sudo rm /etc/systemd/system/ai-dialogue-backend.service
sudo systemctl daemon-reload

# 可选：删除用户和文件
sudo userdel backend
sudo rm -rf /opt/ai-dialogue-backend
sudo rm -rf /var/log/ai-dialogue-backend
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

#### 6. SystemD服务问题

**服务启动失败：**
```bash
# 查看详细错误信息
sudo systemctl status ai-dialogue-backend -l
sudo journalctl -u ai-dialogue-backend -n 50

# 检查服务配置
sudo systemctl cat ai-dialogue-backend

# 验证配置语法
sudo systemd-analyze verify /etc/systemd/system/ai-dialogue-backend.service
```

**权限问题：**
```bash
# 检查文件权限
ls -la /opt/ai-dialogue-backend/
ls -la /var/log/ai-dialogue-backend/

# 修复权限
sudo chown -R backend:backend /opt/ai-dialogue-backend
sudo chown -R backend:backend /var/log/ai-dialogue-backend
```

**环境变量问题：**
```bash
# 检查服务中的环境变量
sudo systemctl show ai-dialogue-backend -p Environment

# 测试手动启动
sudo -u backend bash
cd /opt/ai-dialogue-backend
source venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

#### 7. 网络连接问题
```bash
# 检查防火墙设置
sudo ufw allow 8000
sudo firewall-cmd --permanent --add-port=8000/tcp

# 检查服务绑定
sudo netstat -tlnp | grep :8000

# 确认服务监听正确的地址
# 应该显示 0.0.0.0:8000 而不是 127.0.0.1:8000
```

### 日志调试

#### 查看实时日志
```bash
# SystemD服务日志
sudo journalctl -u ai-dialogue-backend -f

# 应用日志
sudo tail -f /var/log/ai-dialogue-backend/app.log

# 筛选特定级别日志
sudo journalctl -u ai-dialogue-backend | grep ERROR
```

#### 性能监控
```bash
# 系统资源使用
htop
ps aux | grep python

# 服务状态
sudo systemctl status ai-dialogue-backend

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
```bash
# 服务管理
sudo systemctl {start|stop|restart|status} ai-dialogue-backend

# 日志查看  
sudo journalctl -u ai-dialogue-backend -f

# 健康检查
curl http://localhost:8000/

# 配置检查
sudo systemctl cat ai-dialogue-backend

# 自动安装
sudo ./install-service.sh

# 卸载服务
sudo ./install-service.sh --uninstall
```