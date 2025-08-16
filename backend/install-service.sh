#!/bin/bash

# AI对话应用后端 - SystemD服务安装脚本

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

# 配置变量
SERVICE_NAME="ai-dialogue-backend"
SERVICE_USER="backend"
SERVICE_GROUP="backend"
INSTALL_DIR="/opt/ai-dialogue-backend"
LOG_DIR="/var/log/ai-dialogue-backend"
SERVICE_FILE="ai-dialogue-backend.service"

show_help() {
    cat << EOF
AI对话应用后端 - SystemD服务安装脚本

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  -u, --user USER      指定服务运行用户 (默认: $SERVICE_USER)
  -d, --dir DIR        指定安装目录 (默认: $INSTALL_DIR)
  --uninstall          卸载服务
  --status             查看服务状态
  --logs               查看服务日志

安装步骤:
  1. 创建服务用户和组
  2. 创建必要目录
  3. 复制项目文件
  4. 安装Python依赖
  5. 配置systemd服务
  6. 启动服务

要求:
  - Ubuntu/Debian或CentOS/RHEL系统
  - Python 3.12+
  - sudo权限

EOF
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi
    
    # 检查systemd
    if ! command -v systemctl &> /dev/null; then
        log_error "系统不支持systemd"
        exit 1
    fi
    
    # 检查Python版本
    if command -v python3.12 &> /dev/null; then
        PYTHON_CMD="python3.12"
    elif command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if [[ $(echo "$PYTHON_VERSION >= 3.9" | bc -l) -eq 1 ]]; then
            PYTHON_CMD="python3"
        else
            log_error "需要Python 3.9+，当前版本: $PYTHON_VERSION"
            exit 1
        fi
    else
        log_error "未找到Python 3.9+"
        exit 1
    fi
    
    log_info "Python命令: $PYTHON_CMD"
    
    # 检查sudo权限
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            log_error "需要sudo权限"
            exit 1
        fi
    fi
    
    log_success "系统要求检查通过"
}

# 创建用户和组
create_user() {
    log_info "创建服务用户和组..."
    
    # 创建组
    if ! getent group "$SERVICE_GROUP" &> /dev/null; then
        sudo groupadd --system "$SERVICE_GROUP"
        log_info "已创建组: $SERVICE_GROUP"
    else
        log_info "组已存在: $SERVICE_GROUP"
    fi
    
    # 创建用户
    if ! getent passwd "$SERVICE_USER" &> /dev/null; then
        sudo useradd --system --gid "$SERVICE_GROUP" --create-home \
            --home-dir "$INSTALL_DIR" --shell /bin/bash \
            --comment "AI Dialogue Backend Service" "$SERVICE_USER"
        log_info "已创建用户: $SERVICE_USER"
    else
        log_info "用户已存在: $SERVICE_USER"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    # 安装目录
    sudo mkdir -p "$INSTALL_DIR"
    
    # 日志目录
    sudo mkdir -p "$LOG_DIR"
    
    # 模型目录
    sudo mkdir -p "$INSTALL_DIR/model"
    
    # 配置目录
    sudo mkdir -p "$INSTALL_DIR/config"
    
    # 设置权限
    sudo chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
    sudo chown -R "$SERVICE_USER:$SERVICE_GROUP" "$LOG_DIR"
    
    log_success "目录结构创建完成"
}

# 复制项目文件
copy_project_files() {
    log_info "复制项目文件..."
    
    # 获取当前脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 复制应用代码
    sudo cp -r "$SCRIPT_DIR/app" "$INSTALL_DIR/"
    sudo cp -r "$SCRIPT_DIR/config" "$INSTALL_DIR/"
    
    # 复制配置文件
    if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
        sudo cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
    fi
    
    # 复制模型文件（如果存在）
    if [[ -d "$SCRIPT_DIR/model" ]]; then
        sudo cp -r "$SCRIPT_DIR/model"/* "$INSTALL_DIR/model/"
    fi
    
    # 设置权限
    sudo chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
    
    log_success "项目文件复制完成"
}

# 安装Python依赖
install_python_deps() {
    log_info "安装Python依赖..."
    
    # 创建虚拟环境
    sudo -u "$SERVICE_USER" "$PYTHON_CMD" -m venv "$INSTALL_DIR/venv"
    
    # 升级pip
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip
    
    # 安装依赖
    if [[ -f "$INSTALL_DIR/requirements.txt" ]]; then
        sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"
    else
        log_warning "未找到requirements.txt，手动安装依赖"
        sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install fastapi uvicorn websockets pydantic python-dotenv
    fi
    
    log_success "Python依赖安装完成"
}

# 配置systemd服务
configure_service() {
    log_info "配置systemd服务..."
    
    # 复制服务文件
    if [[ -f "$SERVICE_FILE" ]]; then
        sudo cp "$SERVICE_FILE" "/etc/systemd/system/"
    else
        log_error "未找到服务文件: $SERVICE_FILE"
        exit 1
    fi
    
    # 重新加载systemd
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable "$SERVICE_NAME"
    
    log_success "systemd服务配置完成"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    # 启动服务
    sudo systemctl start "$SERVICE_NAME"
    
    # 等待启动
    sleep 3
    
    # 检查状态
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "服务启动成功"
        
        # 显示状态
        sudo systemctl status "$SERVICE_NAME" --no-pager -l
        
        # 测试健康检查
        log_info "测试服务..."
        sleep 2
        
        if curl -s "http://localhost:8000/" &> /dev/null; then
            log_success "服务测试通过"
            curl -s "http://localhost:8000/" | jq . 2>/dev/null || curl -s "http://localhost:8000/"
        else
            log_warning "服务可能尚未完全启动，请稍后测试"
        fi
    else
        log_error "服务启动失败"
        sudo systemctl status "$SERVICE_NAME" --no-pager -l
        exit 1
    fi
}

# 卸载服务
uninstall_service() {
    log_info "卸载服务..."
    
    # 停止服务
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 禁用服务
    if sudo systemctl is-enabled --quiet "$SERVICE_NAME"; then
        sudo systemctl disable "$SERVICE_NAME"
    fi
    
    # 删除服务文件
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    
    # 重新加载systemd
    sudo systemctl daemon-reload
    
    # 询问是否删除用户和文件
    echo -n "是否删除用户、安装目录和日志？(y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # 删除用户
        sudo userdel "$SERVICE_USER" 2>/dev/null || true
        sudo groupdel "$SERVICE_GROUP" 2>/dev/null || true
        
        # 删除目录
        sudo rm -rf "$INSTALL_DIR"
        sudo rm -rf "$LOG_DIR"
        
        log_info "已删除用户和目录"
    fi
    
    log_success "服务卸载完成"
}

# 查看服务状态
show_status() {
    echo "=== 服务状态 ==="
    sudo systemctl status "$SERVICE_NAME" --no-pager -l || true
    
    echo -e "\n=== 服务是否启用 ==="
    sudo systemctl is-enabled "$SERVICE_NAME" || true
    
    echo -e "\n=== 服务是否运行 ==="
    sudo systemctl is-active "$SERVICE_NAME" || true
    
    echo -e "\n=== 端口监听 ==="
    sudo netstat -tlnp | grep ":8000" || echo "端口8000未监听"
    
    echo -e "\n=== 健康检查 ==="
    curl -s "http://localhost:8000/" | jq . 2>/dev/null || curl -s "http://localhost:8000/" || echo "健康检查失败"
}

# 查看服务日志
show_logs() {
    echo "=== 服务日志 (最近50行) ==="
    sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    
    echo -e "\n=== 应用日志 ==="
    if [[ -f "$LOG_DIR/app.log" ]]; then
        sudo tail -n 20 "$LOG_DIR/app.log"
    else
        echo "应用日志文件不存在"
    fi
}

# 主函数
main() {
    local uninstall=false
    local status=false
    local logs=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--user)
                SERVICE_USER="$2"
                shift 2
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --uninstall)
                uninstall=true
                shift
                ;;
            --status)
                status=true
                shift
                ;;
            --logs)
                logs=true
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
    if [[ "$uninstall" == "true" ]]; then
        uninstall_service
    elif [[ "$status" == "true" ]]; then
        show_status
    elif [[ "$logs" == "true" ]]; then
        show_logs
    else
        # 完整安装流程
        echo -e "${BLUE}开始安装AI对话应用后端服务${NC}"
        echo "安装目录: $INSTALL_DIR"
        echo "服务用户: $SERVICE_USER"
        echo
        
        check_requirements
        create_user
        create_directories
        copy_project_files
        install_python_deps
        configure_service
        start_service
        
        echo
        log_success "安装完成！"
        echo
        echo "服务管理命令:"
        echo "  sudo systemctl start $SERVICE_NAME     # 启动服务"
        echo "  sudo systemctl stop $SERVICE_NAME      # 停止服务"
        echo "  sudo systemctl restart $SERVICE_NAME   # 重启服务"
        echo "  sudo systemctl status $SERVICE_NAME    # 查看状态"
        echo "  sudo journalctl -u $SERVICE_NAME -f    # 查看日志"
        echo
        echo "健康检查: curl http://localhost:8000/"
    fi
}

# 执行主函数
main "$@"