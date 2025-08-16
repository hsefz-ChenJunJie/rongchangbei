#!/bin/bash

# AI对话应用后端 - 开发环境启动脚本
# 支持热重载的Docker开发环境

set -e

echo "🚀 启动AI对话应用后端开发环境..."

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ 错误: Docker未运行，请先启动Docker"
    exit 1
fi

# 检查必要文件
if [ ! -f "Dockerfile.dev" ]; then
    echo "❌ 错误: 未找到Dockerfile.dev文件"
    exit 1
fi

if [ ! -f "docker-compose.dev.yml" ]; then
    echo "❌ 错误: 未找到docker-compose.dev.yml文件"
    exit 1
fi

# 创建必要的目录
echo "📁 创建必要的目录..."
mkdir -p logs model

# 检查是否存在.env文件，如果不存在则复制示例
if [ ! -f ".env" ]; then
    if [ -f "config/.env.example" ]; then
        echo "📋 复制环境变量配置文件..."
        cp config/.env.example .env
        echo "⚠️  请编辑 .env 文件并设置您的API密钥"
    else
        echo "⚠️  警告: 未找到.env.example文件，将使用默认配置"
    fi
fi

# 停止可能正在运行的容器
echo "🛑 停止现有容器..."
docker-compose -f docker-compose.dev.yml down --remove-orphans || true

# 构建开发环境镜像
echo "🔨 构建开发环境Docker镜像..."
docker-compose -f docker-compose.dev.yml build --no-cache

# 启动开发环境
echo "🎯 启动开发环境（支持热重载）..."
docker-compose -f docker-compose.dev.yml up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# 检查服务状态
echo "🔍 检查服务状态..."
docker-compose -f docker-compose.dev.yml ps

# 显示日志
echo "📋 显示服务日志（Ctrl+C 退出日志查看）："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose -f docker-compose.dev.yml logs -f ai-backend-dev

echo "🎉 开发环境已启动！"
echo "📡 应用地址: http://localhost:8000"
echo "🔧 API文档: http://localhost:8000/docs" 
echo "💬 WebSocket: ws://localhost:8000/conversation"
echo "❤️  健康检查: http://localhost:8000/"
echo ""
echo "📝 常用命令:"
echo "  停止开发环境: docker-compose -f docker-compose.dev.yml down"
echo "  查看日志: docker-compose -f docker-compose.dev.yml logs -f"
echo "  重启服务: docker-compose -f docker-compose.dev.yml restart"
echo "  进入容器: docker-compose -f docker-compose.dev.yml exec ai-backend-dev bash"