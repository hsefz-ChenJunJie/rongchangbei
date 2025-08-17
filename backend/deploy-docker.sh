#!/bin/bash

# AI对话应用后端 - Docker部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
AI对话应用后端 - Docker部署脚本

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  --build              强制重新构建镜像
  --no-cache           构建时不使用缓存
  --pull               拉取最新基础镜像
  --logs               查看服务日志
  --stop               停止服务
  --restart            重启服务
  --status             查看服务状态
  --clean              清理未使用的Docker资源

部署步骤:
  1. 检查Docker环境
  2. 创建必要目录
  3. 设置环境变量
  4. 构建Docker镜像
  5. 启动服务

要求:
  - Docker 20.0+
  - Docker Compose 2.0+

EOF
}

# 检查Docker环境
check_docker() {
    log_info "检查Docker环境..."
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        log_info "安装指南: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker守护进程未运行，请启动Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose未安装或版本过低"
        log_info "需要Docker Compose 2.0+版本"
        exit 1
    fi
    
    # 启用Docker BuildKit
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    COMPOSE_VERSION=$(docker compose version --short)
    
    log_success "Docker环境检查通过"
    log_info "Docker版本: $DOCKER_VERSION"
    log_info "Docker Compose版本: $COMPOSE_VERSION"
    log_info "BuildKit已启用"
}

# 创建必要目录
create_directories() {
    log_info "创建必要目录..."
    
    # 创建日志目录
    mkdir -p logs
    
    # 设置权限
    chmod 755 logs
    
    log_success "目录创建完成"
}

# 设置环境变量
setup_env() {
    log_info "设置环境变量..."
    
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            log_info "复制 .env.example 到 .env"
            cp .env.example .env
            log_warning "请编辑 .env 文件配置您的API密钥等参数"
        else
            log_warning "未找到 .env.example 文件，使用默认配置"
        fi
    else
        log_info ".env 文件已存在"
    fi
    
    log_success "环境变量设置完成"
}

# 构建和启动服务
deploy_service() {
    local build_flag=""
    local cache_flag=""
    local pull_flag=""
    
    if [[ "$FORCE_BUILD" == "true" ]]; then
        build_flag="--build"
    fi
    
    if [[ "$NO_CACHE" == "true" ]]; then
        cache_flag="--no-cache"
    fi
    
    if [[ "$PULL_IMAGES" == "true" ]]; then
        pull_flag="--pull"
    fi
    
    log_info "构建和启动服务..."
    
    # 显示构建配置
    log_info "构建配置:"
    log_info "- BuildKit: 已启用"
    log_info "- 缓存挂载: 已启用"
    log_info "- 镜像源: 阿里云镜像"
    log_info "- 包管理器: uv (快速安装)"
    
    # 记录构建开始时间
    BUILD_START=$(date +%s)
    
    # 停止现有服务
    docker compose down 2>/dev/null || true
    
    # 构建和启动
    if [[ -n "$build_flag" || -n "$cache_flag" || -n "$pull_flag" ]]; then
        log_info "开始镜像构建..."
        docker compose build $cache_flag $pull_flag
        BUILD_END=$(date +%s)
        BUILD_TIME=$((BUILD_END - BUILD_START))
        log_success "镜像构建完成，耗时: ${BUILD_TIME}秒"
    fi
    
    log_info "启动容器..."
    docker compose up -d $build_flag
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker compose ps | grep -q "Up"; then
        log_success "服务启动成功"
        
        # 显示服务信息
        echo
        log_info "服务信息:"
        docker compose ps
        
        echo
        log_info "日志预览:"
        docker compose logs --tail=20
        
        echo
        log_success "部署完成！"
        echo "访问地址: http://localhost:8000"
        echo "健康检查: curl http://localhost:8000/"
        echo "查看日志: $0 --logs"
        echo "停止服务: $0 --stop"
    else
        log_error "服务启动失败"
        echo
        log_info "错误日志:"
        docker compose logs
        exit 1
    fi
}

# 查看日志
show_logs() {
    log_info "查看服务日志..."
    docker compose logs -f
}

# 停止服务
stop_service() {
    log_info "停止服务..."
    docker compose down
    log_success "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启服务..."
    docker compose restart
    sleep 5
    log_success "服务已重启"
    docker compose ps
}

# 查看状态
show_status() {
    echo "=== 容器状态 ==="
    docker compose ps
    
    echo -e "\n=== 资源使用 ==="
    docker stats --no-stream $(docker compose ps -q) 2>/dev/null || echo "无运行中的容器"
    
    echo -e "\n=== 健康检查 ==="
    if curl -s --max-time 5 "http://localhost:8000/" &> /dev/null; then
        echo "✓ 服务可访问: http://localhost:8000/"
    else
        echo "✗ 服务不可访问"
    fi
    
    echo -e "\n=== 最新日志 ==="
    docker compose logs --tail=10
}

# 清理资源
clean_resources() {
    log_info "清理Docker资源..."
    
    echo -n "是否清理未使用的Docker镜像和容器？(y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        docker system prune -f
        log_success "清理完成"
    else
        log_info "跳过清理"
    fi
}

# 主函数
main() {
    local force_build=false
    local no_cache=false
    local pull_images=false
    local show_logs_flag=false
    local stop_flag=false
    local restart_flag=false
    local status_flag=false
    local clean_flag=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --build)
                FORCE_BUILD=true
                shift
                ;;
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            --pull)
                PULL_IMAGES=true
                shift
                ;;
            --logs)
                show_logs_flag=true
                shift
                ;;
            --stop)
                stop_flag=true
                shift
                ;;
            --restart)
                restart_flag=true
                shift
                ;;
            --status)
                status_flag=true
                shift
                ;;
            --clean)
                clean_flag=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 执行操作
    if [[ "$show_logs_flag" == "true" ]]; then
        show_logs
    elif [[ "$stop_flag" == "true" ]]; then
        stop_service
    elif [[ "$restart_flag" == "true" ]]; then
        restart_service
    elif [[ "$status_flag" == "true" ]]; then
        show_status
    elif [[ "$clean_flag" == "true" ]]; then
        clean_resources
    else
        # 默认部署流程
        echo -e "${BLUE}开始部署AI对话应用后端 (Docker)${NC}"
        echo
        
        check_docker
        create_directories
        setup_env
        deploy_service
    fi
}

# 执行主函数
main "$@"