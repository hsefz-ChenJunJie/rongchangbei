# 开发环境部署指南

## 概述

本项目提供了支持热重载的Docker开发环境，可以在代码更改时自动重启服务，大大提升开发效率。

## 文件说明

### 核心文件
- `Dockerfile.dev` - 开发环境专用的Dockerfile
- `docker-compose.dev.yml` - 开发环境的Docker Compose配置
- `dev-start.sh` - 开发环境启动脚本
- `validate-compose.sh` - Docker Compose配置验证脚本

### 与生产环境的区别

| 配置项 | 生产环境 | 开发环境 |
|--------|----------|----------|
| DEBUG模式 | false | true |
| 日志级别 | INFO | DEBUG |
| Vosk STT | 真实服务 | Mock模式 |
| 代码挂载 | 不挂载 | 热重载挂载 |
| 启动参数 | 标准启动 | --reload |
| 开发工具 | 无 | 包含调试工具 |

## 快速开始

### 1. 验证环境

```bash
# 检查Docker是否运行
docker --version
docker-compose --version

# 验证配置文件语法
./validate-compose.sh
```

### 2. 启动开发环境

```bash
# 使用启动脚本（推荐）
./dev-start.sh

# 或手动启动
docker-compose -f docker-compose.dev.yml up --build
```

### 3. 访问服务

- **应用地址**: http://localhost:8000
- **API文档**: http://localhost:8000/docs
- **WebSocket**: ws://localhost:8000/conversation
- **健康检查**: http://localhost:8000/

## 热重载功能

### 自动重载触发条件
- Python文件修改 (`.py`)
- 配置文件修改 (`.env`, `settings.py`)
- 模板文件修改

### 重载范围
- **包含**: `/app` 目录下的所有Python代码
- **排除**: 日志文件、缓存文件、`__pycache__`

### 重载时间
- 文件保存后 1-3 秒内自动重启
- 无需手动重启容器

## 常用开发命令

### 基础操作

```bash
# 启动开发环境
docker-compose -f docker-compose.dev.yml up -d

# 查看服务状态
docker-compose -f docker-compose.dev.yml ps

# 查看实时日志
docker-compose -f docker-compose.dev.yml logs -f ai-backend-dev

# 停止开发环境
docker-compose -f docker-compose.dev.yml down

# 重启服务
docker-compose -f docker-compose.dev.yml restart ai-backend-dev
```

### 调试操作

```bash
# 进入开发容器
docker-compose -f docker-compose.dev.yml exec ai-backend-dev bash

# 在容器内运行测试
docker-compose -f docker-compose.dev.yml exec ai-backend-dev python -m pytest

# 查看容器内进程
docker-compose -f docker-compose.dev.yml exec ai-backend-dev ps aux

# 查看环境变量
docker-compose -f docker-compose.dev.yml exec ai-backend-dev env | grep -E "(HOST|PORT|DEBUG)"
```

### 代码质量检查

```bash
# 代码格式化
docker-compose -f docker-compose.dev.yml exec ai-backend-dev black app/

# 代码风格检查
docker-compose -f docker-compose.dev.yml exec ai-backend-dev flake8 app/

# 类型检查
docker-compose -f docker-compose.dev.yml exec ai-backend-dev mypy app/

# 导入排序
docker-compose -f docker-compose.dev.yml exec ai-backend-dev isort app/
```

## 配置说明

### 环境变量配置

开发环境使用以下特殊配置：

```yaml
environment:
  - DEBUG=true              # 启用调试模式
  - LOG_LEVEL=DEBUG         # 详细日志输出
  - USE_REAL_VOSK=false     # 使用Mock STT服务
  - ALLOWED_ORIGINS=["*"]   # 允许所有跨域请求
```

### 卷挂载配置

```yaml
volumes:
  - .:/app:rw                 # 源代码热重载
  - ./logs:/app/logs:rw       # 日志文件本地化
  - ./model:/app/model:ro     # 模型文件只读挂载
```

### 启动命令

```yaml
command: [
  "python", "-m", "uvicorn", "app.main:app",
  "--host", "0.0.0.0",
  "--port", "8000",
  "--reload",                 # 启用热重载
  "--reload-dir", "/app",     # 监控目录
  "--log-level", "debug"      # 详细日志
]
```

## 故障排除

### 常见问题

#### 1. 容器无法启动
```bash
# 检查语法
./validate-compose.sh

# 查看详细错误
docker-compose -f docker-compose.dev.yml up

# 清理并重建
docker-compose -f docker-compose.dev.yml down --volumes
docker-compose -f docker-compose.dev.yml build --no-cache
```

#### 2. 热重载不工作
```bash
# 检查文件挂载
docker-compose -f docker-compose.dev.yml exec ai-backend-dev ls -la /app

# 检查uvicorn进程
docker-compose -f docker-compose.dev.yml exec ai-backend-dev ps aux | grep uvicorn

# 重启服务
docker-compose -f docker-compose.dev.yml restart ai-backend-dev
```

#### 3. 端口冲突
```bash
# 检查端口占用
lsof -i :8000

# 修改端口（在docker-compose.dev.yml中）
ports:
  - "8001:8000"  # 改为8001
```

#### 4. 权限问题
```bash
# 检查文件权限
ls -la

# 修正权限
sudo chown -R $USER:$USER .
```

### 日志分析

```bash
# 查看启动日志
docker-compose -f docker-compose.dev.yml logs ai-backend-dev | head -50

# 查看错误日志
docker-compose -f docker-compose.dev.yml logs ai-backend-dev | grep -i error

# 查看热重载日志
docker-compose -f docker-compose.dev.yml logs ai-backend-dev | grep -i reload
```

## 性能优化建议

### 开发环境优化
1. **使用SSD硬盘** - 提高文件监控性能
2. **限制监控目录** - 只监控必要的代码目录
3. **排除大文件** - 在`.dockerignore`中排除不必要的文件
4. **使用缓存** - 合理利用Docker层缓存

### 资源配置
```yaml
# 可选：限制开发环境资源使用
deploy:
  resources:
    limits:
      cpus: '1.0'      # 限制CPU使用
      memory: 2G       # 限制内存使用
```

## 扩展配置

### 添加数据库服务

如需在开发环境中添加数据库，可以取消注释docker-compose.dev.yml中的相关配置：

```yaml
postgres-dev:
  image: postgres:15-alpine
  environment:
    - POSTGRES_DB=ai_dialogue_dev
    - POSTGRES_USER=dev_user
    - POSTGRES_PASSWORD=dev_password
  ports:
    - "5432:5432"
```

### 添加Redis缓存

```yaml
redis-dev:
  image: redis:7-alpine
  ports:
    - "6379:6379"
```

## 与生产环境同步

### 配置差异检查
```bash
# 比较生产和开发环境配置
diff docker-compose.yml docker-compose.dev.yml
```

### 生产环境测试
```bash
# 在开发环境中测试生产配置
docker-compose -f docker-compose.yml up --build
```

## 最佳实践

1. **定期更新依赖** - 保持开发环境与生产环境同步
2. **及时提交代码** - 热重载时及时保存和提交更改
3. **监控资源使用** - 避免开发环境消耗过多系统资源
4. **备份重要配置** - 定期备份开发环境配置
5. **文档更新** - 配置变更时及时更新文档

---

## 支持与反馈

如遇到问题，请查看：
1. 项目主文档 `README.md`
2. 配置文档 `CONFIGURATION.md`
3. 故障排除章节
4. 项目Issue页面