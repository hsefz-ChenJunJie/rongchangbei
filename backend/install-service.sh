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
CONDA_ENV="rongchang"  # 指定使用的conda环境名

# 检测运行环境
if [[ "$EUID" -eq 0 ]]; then
    if [[ -z "$SUDO_USER" ]]; then
        log_warning "检测到以root用户直接运行，某些功能可能受限"
    else
        log_info "检测到sudo环境，原用户: $SUDO_USER"
    fi
fi

show_help() {
    cat << EOF
AI对话应用后端 - SystemD服务安装脚本

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  -u, --user USER      指定服务运行用户 (默认: $SERVICE_USER)
  -d, --dir DIR        指定安装目录 (默认: $INSTALL_DIR)
  -e, --env ENV        指定conda环境名 (默认: $CONDA_ENV)
  --uninstall          卸载服务
  --status             查看服务状态
  --logs               查看服务日志
  --debug              显示详细的环境诊断信息

安装步骤:
  1. 创建服务用户和组
  2. 创建必要目录
  3. 复制项目文件
  4. 安装Python依赖
  5. 配置systemd服务
  6. 启动服务

要求:
  - Ubuntu/Debian或CentOS/RHEL系统
  - Conda环境管理器 (miniconda/anaconda)
  - 指定conda环境中包含Python 3.12+
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
    
    # 检查conda - 考虑sudo环境
    CONDA_COMMAND=""
    
    # 构建所有可能的conda路径（优先级排序）
    POSSIBLE_CONDA_PATHS=(
        # 用户HOME目录下的conda安装
        "/home/$SUDO_USER/miniconda3/bin/conda"
        "/home/$SUDO_USER/anaconda3/bin/conda"
        "/home/$SUDO_USER/.conda/bin/conda"
        "/home/$SUDO_USER/.local/bin/conda"
        # 系统级安装路径
        "/usr/local/miniconda3/bin/conda"  # 添加这个关键路径
        "/usr/local/anaconda3/bin/conda"
        "/usr/local/conda/bin/conda"
        "/opt/miniconda3/bin/conda"
        "/opt/anaconda3/bin/conda"
        "/opt/conda/bin/conda"
        # 其他可能的路径
        "/usr/bin/conda"
        "/usr/local/bin/conda"
    )
    
    # 方法1：优先在常见路径中查找conda（sudo环境下PATH不可靠）
    for conda_path in "${POSSIBLE_CONDA_PATHS[@]}"; do
        if [[ -f "$conda_path" && -x "$conda_path" ]]; then
            CONDA_COMMAND="$conda_path"
            log_info "在路径找到conda: $conda_path"
            break
        fi
    done
    
    # 方法2：如果路径查找失败，再尝试PATH中的conda命令
    if [[ -z "$CONDA_COMMAND" ]] && command -v conda &> /dev/null; then
        CONDA_COMMAND="conda"
        log_info "在PATH中找到conda命令: $(which conda)"
    fi
    
    # 方法3：对于sudo环境，额外处理
    if [[ -z "$CONDA_COMMAND" ]]; then
        
        # 使用sudo -u 原用户查找conda
        if [[ -n "$SUDO_USER" ]]; then
            # 尝试以原用户身份查找conda
            ORIGINAL_CONDA_PATH=$(sudo -u "$SUDO_USER" bash -c "command -v conda 2>/dev/null || echo ''")
            if [[ -n "$ORIGINAL_CONDA_PATH" && -f "$ORIGINAL_CONDA_PATH" && -x "$ORIGINAL_CONDA_PATH" ]]; then
                CONDA_COMMAND="$ORIGINAL_CONDA_PATH"
                log_info "通过sudo -u $SUDO_USER 找到conda: $ORIGINAL_CONDA_PATH"
            else
                # 尝试以原用户身份source环境后查找conda
                ORIGINAL_CONDA_PATH=$(sudo -u "$SUDO_USER" bash -c "
                    source ~/.bashrc 2>/dev/null || true
                    source ~/.zshrc 2>/dev/null || true
                    command -v conda 2>/dev/null || echo ''
                ")
                if [[ -n "$ORIGINAL_CONDA_PATH" && -f "$ORIGINAL_CONDA_PATH" && -x "$ORIGINAL_CONDA_PATH" ]]; then
                    CONDA_COMMAND="$ORIGINAL_CONDA_PATH"
                    log_info "通过sudo -u $SUDO_USER 环境source找到conda: $ORIGINAL_CONDA_PATH"
                fi
            fi
        fi
    fi
    
    if [[ -z "$CONDA_COMMAND" ]]; then
        log_error "未找到conda，请先安装miniconda/anaconda"
        log_info "如果conda已安装但未找到，请尝试："
        log_info "1. 检查conda是否在PATH中: which conda"
        log_info "2. 如果是sudo环境，请确保原用户能访问conda"
        log_info "3. 检查常见安装位置："
        log_info "   - /usr/local/miniconda3/bin/conda"
        log_info "   - /opt/miniconda3/bin/conda"
        log_info "   - /home/\$USER/miniconda3/bin/conda"
        log_info "4. 使用--debug参数查看详细诊断信息"
        exit 1
    fi
    
    log_info "使用conda命令: $CONDA_COMMAND"
    
    # 检查指定的conda环境是否存在
    ENV_CHECK_RESULT=""
    if [[ -n "$SUDO_USER" ]]; then
        # 在sudo环境下以原用户身份检查
        ENV_CHECK_RESULT=$(sudo -u "$SUDO_USER" bash -c "
            source ~/.bashrc 2>/dev/null || true
            source ~/.zshrc 2>/dev/null || true
            '$CONDA_COMMAND' env list 2>/dev/null | grep '^${CONDA_ENV} ' || echo ''
        ")
    else
        ENV_CHECK_RESULT=$($CONDA_COMMAND env list 2>/dev/null | grep "^${CONDA_ENV} " || echo "")
    fi
    
    if [[ -z "$ENV_CHECK_RESULT" ]]; then
        log_error "Conda环境 '${CONDA_ENV}' 不存在"
        log_info "请创建环境: conda create -n ${CONDA_ENV} python=3.12"
        exit 1
    fi
    
    # 获取conda环境中的Python路径 - 使用多种方法确保兼容性
    CONDA_PREFIX=""
    
    # 定义执行conda命令的函数
    run_conda_cmd() {
        local cmd="$1"
        if [[ -n "$SUDO_USER" ]]; then
            sudo -u "$SUDO_USER" bash -c "
                source ~/.bashrc 2>/dev/null || true
                source ~/.zshrc 2>/dev/null || true
                '$CONDA_COMMAND' $cmd 2>/dev/null || echo ''
            "
        else
            $CONDA_COMMAND $cmd 2>/dev/null || echo ""
        fi
    }
    
    # 方法1：使用conda info --envs（最常用方法）
    if [[ -z "$CONDA_PREFIX" ]]; then
        CONDA_PREFIX=$(run_conda_cmd "info --envs" | grep "^${CONDA_ENV} " | awk '{print $2}')
        if [[ -n "$CONDA_PREFIX" ]]; then
            log_info "方法1成功：conda info --envs 获取路径 $CONDA_PREFIX"
        fi
    fi
    
    # 方法2：尝试不同的awk字段
    if [[ -z "$CONDA_PREFIX" ]]; then
        CONDA_PREFIX=$(run_conda_cmd "info --envs" | grep " ${CONDA_ENV} " | awk '{print $3}')
        if [[ -n "$CONDA_PREFIX" ]]; then
            log_info "方法2成功：conda info --envs (字段3) 获取路径 $CONDA_PREFIX"
        fi
    fi
    
    # 方法3：使用conda env list
    if [[ -z "$CONDA_PREFIX" ]]; then
        CONDA_PREFIX=$(run_conda_cmd "env list" | grep "^${CONDA_ENV} " | awk '{print $2}')
        if [[ -n "$CONDA_PREFIX" ]]; then
            log_info "方法3成功：conda env list 获取路径 $CONDA_PREFIX"
        fi
    fi
    
    # 方法4：使用conda activate获取CONDA_PREFIX
    if [[ -z "$CONDA_PREFIX" ]]; then
        # 创建临时脚本来获取激活后的CONDA_PREFIX
        TEMP_SCRIPT=$(mktemp)
        if [[ -n "$SUDO_USER" ]]; then
            # 为原用户创建临时脚本
            cat << EOF > "$TEMP_SCRIPT"
#!/bin/bash
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
eval "\$('$CONDA_COMMAND' shell.bash hook)" 2>/dev/null || true
'$CONDA_COMMAND' activate ${CONDA_ENV} 2>/dev/null && echo "\$CONDA_PREFIX"
EOF
            CONDA_PREFIX=$(sudo -u "$SUDO_USER" bash "$TEMP_SCRIPT")
        else
            cat << EOF > "$TEMP_SCRIPT"
#!/bin/bash
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
eval "\$('$CONDA_COMMAND' shell.bash hook)" 2>/dev/null || true
'$CONDA_COMMAND' activate ${CONDA_ENV} 2>/dev/null && echo "\$CONDA_PREFIX"
EOF
            CONDA_PREFIX=$(bash "$TEMP_SCRIPT")
        fi
        rm -f "$TEMP_SCRIPT"
        if [[ -n "$CONDA_PREFIX" ]]; then
            log_info "方法4成功：通过conda activate获取路径 $CONDA_PREFIX"
        fi
    fi
    
    # 方法5：使用环境变量（如果当前已激活该环境）
    if [[ -z "$CONDA_PREFIX" ]] && [[ "$CONDA_DEFAULT_ENV" == "$CONDA_ENV" ]]; then
        if [[ -n "$CONDA_PREFIX_BACKUP" ]]; then
            CONDA_PREFIX="$CONDA_PREFIX_BACKUP"
            log_info "方法5成功：使用当前激活环境的CONDA_PREFIX $CONDA_PREFIX"
        fi
    fi
    
    # 方法6：直接构造路径（基于常见conda安装位置）
    if [[ -z "$CONDA_PREFIX" ]]; then
        # 尝试常见的conda安装位置
        POSSIBLE_PATHS=(
            "$HOME/.conda/envs/${CONDA_ENV}"
            "$HOME/miniconda3/envs/${CONDA_ENV}"
            "$HOME/anaconda3/envs/${CONDA_ENV}"
            "/opt/conda/envs/${CONDA_ENV}"
            "/usr/local/conda/envs/${CONDA_ENV}"
        )
        
        for path in "${POSSIBLE_PATHS[@]}"; do
            if [[ -d "$path" ]] && [[ -f "$path/bin/python" ]]; then
                CONDA_PREFIX="$path"
                log_info "方法6成功：在常见位置找到环境 $CONDA_PREFIX"
                break
            fi
        done
    fi
    
    # 最终验证
    if [[ -z "$CONDA_PREFIX" ]]; then
        log_error "所有方法均失败，无法获取conda环境 '${CONDA_ENV}' 的路径"
        log_info "请检查以下信息："
        log_info "当前用户: $(whoami)"
        log_info "当前工作目录: $(pwd)"
        log_info "CONDA_DEFAULT_ENV: ${CONDA_DEFAULT_ENV:-未设置}"
        log_info "CONDA_PREFIX: ${CONDA_PREFIX:-未设置}"
        log_info "PATH: $PATH"
        echo
        log_info "请尝试以下命令排查："
        echo "  conda info --envs"
        echo "  conda env list"
        echo "  which conda"
        echo "  conda --version"
        exit 1
    fi
    
    log_info "最终确定的conda环境路径: $CONDA_PREFIX"
    PYTHON_CMD="${CONDA_PREFIX}/bin/python"
    
    # 验证Python路径存在 - 增强版本，支持多种Python可执行文件
    VALID_PYTHON_CMD=""
    
    # 尝试多种Python可执行文件名
    PYTHON_CANDIDATES=(
        "${CONDA_PREFIX}/bin/python"
        "${CONDA_PREFIX}/bin/python3"
        "${CONDA_PREFIX}/bin/python3.12"
        "${CONDA_PREFIX}/bin/python3.11"
        "${CONDA_PREFIX}/bin/python3.10"
    )
    
    for python_path in "${PYTHON_CANDIDATES[@]}"; do
        if [[ -f "$python_path" ]] && [[ -x "$python_path" ]]; then
            VALID_PYTHON_CMD="$python_path"
            log_info "找到可用的Python: $python_path"
            break
        fi
    done
    
    if [[ -z "$VALID_PYTHON_CMD" ]]; then
        log_error "在conda环境 '${CONDA_ENV}' 中找不到Python可执行文件"
        log_info "检查的路径包括："
        for python_path in "${PYTHON_CANDIDATES[@]}"; do
            echo "  - $python_path $(if [[ -f "$python_path" ]]; then echo "(存在但不可执行)"; else echo "(不存在)"; fi)"
        done
        echo
        log_info "故障排除建议："
        echo "1. 确认conda环境已正确创建："
        echo "   conda create -n ${CONDA_ENV} python=3.12"
        echo "2. 检查环境目录权限："
        echo "   ls -la ${CONDA_PREFIX}/bin/"
        echo "3. 手动激活环境并测试："
        echo "   conda activate ${CONDA_ENV}"
        echo "   which python"
        echo "   python --version"
        exit 1
    fi
    
    # 使用找到的有效Python路径
    PYTHON_CMD="$VALID_PYTHON_CMD"
    
    # 获取Python版本并正确比较版本号
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
    
    # 检查版本是否满足要求 (3.12+)
    if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 12 ]]; then
        log_error "需要Python 3.12+，conda环境 '${CONDA_ENV}' 中的版本: $PYTHON_VERSION"
        log_info "请升级环境: conda install -n ${CONDA_ENV} python=3.12"
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
    log_info "在conda环境 '${CONDA_ENV}' 中安装Python依赖..."
    
    # 获取conda环境中的pip路径
    PIP_CMD="${CONDA_PREFIX}/bin/pip"
    
    # 检查conda环境所有者，决定安装策略
    CONDA_OWNER=$(stat -c %U "$CONDA_PREFIX" 2>/dev/null || stat -f %Su "$CONDA_PREFIX" 2>/dev/null || echo "unknown")
    log_info "Conda环境所有者: $CONDA_OWNER"
    
    if [[ -n "$SUDO_USER" && "$CONDA_OWNER" == "$SUDO_USER" ]]; then
        # 以原用户身份安装依赖（推荐方式）
        log_info "以原用户 $SUDO_USER 身份安装依赖"
        
        # 升级pip
        sudo -u "$SUDO_USER" bash -c "
            source ~/.bashrc 2>/dev/null || true
            source ~/.zshrc 2>/dev/null || true
            '$PIP_CMD' install --upgrade pip
        "
        
        # 安装依赖
        # 获取当前脚本所在目录（源目录）
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
            # 直接从源目录读取requirements.txt，避免权限问题
            log_info "从源目录读取requirements.txt: $SCRIPT_DIR/requirements.txt"
            
            sudo -u "$SUDO_USER" bash -c "
                source ~/.bashrc 2>/dev/null || true
                source ~/.zshrc 2>/dev/null || true
                '$PIP_CMD' install -r '$SCRIPT_DIR/requirements.txt'
            "
        elif [[ -f "$INSTALL_DIR/requirements.txt" ]]; then
            # 备选方案：临时调整已复制文件的权限
            log_info "临时调整requirements.txt权限以便原用户读取"
            sudo chmod +r "$INSTALL_DIR/requirements.txt"
            
            sudo -u "$SUDO_USER" bash -c "
                source ~/.bashrc 2>/dev/null || true
                source ~/.zshrc 2>/dev/null || true
                '$PIP_CMD' install -r '$INSTALL_DIR/requirements.txt'
            "
            
            # 恢复文件权限
            sudo chown "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR/requirements.txt"
        else
            log_warning "未找到requirements.txt，手动安装核心依赖"
            sudo -u "$SUDO_USER" bash -c "
                source ~/.bashrc 2>/dev/null || true
                source ~/.zshrc 2>/dev/null || true
                '$PIP_CMD' install fastapi uvicorn websockets pydantic python-dotenv
            "
        fi
        
        # 为service用户创建conda环境访问权限
        log_info "配置service用户对conda环境的访问权限..."
        
        # 将service用户添加到原用户的组（如果可能）
        if getent group "$SUDO_USER" >/dev/null 2>&1; then
            usermod -a -G "$SUDO_USER" "$SERVICE_USER" 2>/dev/null || true
        fi
        
        # 设置conda环境的组访问权限
        if [[ -d "$CONDA_PREFIX" ]]; then
            # 为conda环境目录设置组读取和执行权限
            chmod -R g+rX "$CONDA_PREFIX" 2>/dev/null || true
            log_info "已设置conda环境组访问权限"
        fi
        
    else
        # 回退到原有方式（可能需要权限调整）
        log_warning "无法确定conda环境所有者，尝试直接安装..."
        
        # 升级pip
        sudo -u "$SERVICE_USER" "$PIP_CMD" install --upgrade pip
        
        # 安装依赖
        if [[ -f "$INSTALL_DIR/requirements.txt" ]]; then
            sudo -u "$SERVICE_USER" "$PIP_CMD" install -r "$INSTALL_DIR/requirements.txt"
        else
            log_warning "未找到requirements.txt，手动安装核心依赖"
            sudo -u "$SERVICE_USER" "$PIP_CMD" install fastapi uvicorn websockets pydantic python-dotenv
        fi
    fi
    
    log_success "Python依赖安装完成"
}

# 配置systemd服务
configure_service() {
    log_info "配置systemd服务..."
    
    # 获取当前脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 检查服务文件是否存在
    if [[ ! -f "$SCRIPT_DIR/$SERVICE_FILE" ]]; then
        log_error "未找到服务文件: $SCRIPT_DIR/$SERVICE_FILE"
        exit 1
    fi
    
    # 修复服务文件中的Python路径和目录路径
    log_info "修复服务文件中的Python路径: $PYTHON_CMD"
    
    # 创建临时文件进行路径替换
    TEMP_SERVICE_FILE=$(mktemp)
    
    # 替换服务文件中的路径和配置
    sed \
        -e "s|/opt/ai-dialogue-backend/venv/bin/python|$PYTHON_CMD|g" \
        -e "s|WorkingDirectory=/opt/ai-dialogue-backend|WorkingDirectory=$INSTALL_DIR|g" \
        -e "s|Environment=PATH=/opt/ai-dialogue-backend/venv/bin.*|Environment=PYTHONPATH=$INSTALL_DIR|g" \
        -e "s|Environment=PYTHONPATH=/opt/ai-dialogue-backend|Environment=PYTHONPATH=$INSTALL_DIR|g" \
        -e "s|VOSK_MODEL_PATH=/opt/ai-dialogue-backend/model|VOSK_MODEL_PATH=$INSTALL_DIR/model|g" \
        -e "s|LOG_FILE=/var/log/ai-dialogue-backend|LOG_FILE=$LOG_DIR|g" \
        -e "s|ReadWritePaths=/var/log/ai-dialogue-backend /opt/ai-dialogue-backend/logs|ReadWritePaths=$LOG_DIR $INSTALL_DIR/logs|g" \
        "$SCRIPT_DIR/$SERVICE_FILE" > "$TEMP_SERVICE_FILE"
    
    # 更新原始服务文件
    cp "$TEMP_SERVICE_FILE" "$SCRIPT_DIR/$SERVICE_FILE"
    rm -f "$TEMP_SERVICE_FILE"
    
    log_info "已更新服务文件中的路径配置"
    
    # 复制服务文件到systemd目录
    sudo cp "$SCRIPT_DIR/$SERVICE_FILE" "/etc/systemd/system/"
    
    log_info "使用的Python路径: $PYTHON_CMD"
    log_info "工作目录: $INSTALL_DIR"
    
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

# 显示调试信息
show_debug_info() {
    echo "=== AI对话应用后端 - 环境诊断信息 ==="
    echo "时间: $(date)"
    echo "用户: $(whoami)"
    echo "工作目录: $(pwd)"
    echo "主机名: $(hostname)"
    echo
    
    echo "=== 系统信息 ==="
    if [[ -f /etc/os-release ]]; then
        cat /etc/os-release
    else
        echo "无法获取系统版本信息"
    fi
    echo
    
    echo "=== Shell 环境 ==="
    echo "SHELL: $SHELL"
    echo "CONDA_DEFAULT_ENV: ${CONDA_DEFAULT_ENV:-未设置}"
    echo "CONDA_PREFIX: ${CONDA_PREFIX:-未设置}"
    echo "CONDA_PYTHON_EXE: ${CONDA_PYTHON_EXE:-未设置}"
    echo "PATH: $PATH"
    echo
    
    echo "=== Conda 信息 ==="
    if command -v conda &> /dev/null; then
        echo "Conda 路径: $(which conda)"
        echo "Conda 版本: $(conda --version 2>&1)"
        echo
        echo "Conda 环境列表:"
        conda info --envs 2>&1 || echo "无法获取conda环境列表"
        echo
        echo "Conda 信息:"
        conda info 2>&1 || echo "无法获取conda信息"
    elif [[ -n "$SUDO_USER" ]]; then
        echo "当前用户环境中Conda未找到，尝试检查原用户环境..."
        ORIG_CONDA_PATH=$(sudo -u "$SUDO_USER" bash -c "command -v conda" 2>/dev/null || echo "")
        if [[ -n "$ORIG_CONDA_PATH" ]]; then
            echo "原用户的Conda路径: $ORIG_CONDA_PATH"
            echo "原用户的Conda版本: $(sudo -u "$SUDO_USER" bash -c "conda --version" 2>&1)"
            echo
            echo "原用户的Conda环境列表:"
            sudo -u "$SUDO_USER" bash -c "conda info --envs" 2>&1 || echo "无法获取conda环境列表"
        else
            echo "Conda 未找到（包括原用户环境）"
        fi
    else
        echo "Conda 未找到"
    fi
    echo
    
    echo "=== 指定环境 '${CONDA_ENV}' 详情 ==="
    
    # 检查环境是否存在 - 兼容sudo环境
    ENV_EXISTS=false
    if command -v conda &> /dev/null; then
        if conda env list | grep -q "^${CONDA_ENV} "; then
            ENV_EXISTS=true
        fi
    elif [[ -n "$SUDO_USER" ]]; then
        if sudo -u "$SUDO_USER" bash -c "conda env list" 2>/dev/null | grep -q "^${CONDA_ENV} "; then
            ENV_EXISTS=true
        fi
    fi
    
    if [[ "$ENV_EXISTS" == "true" ]]; then
        echo "环境存在: ✓"
        
        # 尝试获取环境路径 - 兼容sudo环境
        ENV_PATH=""
        if command -v conda &> /dev/null; then
            ENV_PATH=$(conda info --envs | grep "^${CONDA_ENV} " | awk '{print $2}')
            if [[ -z "$ENV_PATH" ]]; then
                ENV_PATH=$(conda info --envs | grep " ${CONDA_ENV} " | awk '{print $3}')
            fi
        elif [[ -n "$SUDO_USER" ]]; then
            ENV_PATH=$(sudo -u "$SUDO_USER" bash -c "conda info --envs" 2>/dev/null | grep "^${CONDA_ENV} " | awk '{print $2}')
            if [[ -z "$ENV_PATH" ]]; then
                ENV_PATH=$(sudo -u "$SUDO_USER" bash -c "conda info --envs" 2>/dev/null | grep " ${CONDA_ENV} " | awk '{print $3}')
            fi
        fi
        
        if [[ -n "$ENV_PATH" ]]; then
            echo "环境路径: $ENV_PATH"
            echo "环境目录内容:"
            ls -la "$ENV_PATH" 2>/dev/null || echo "无法访问环境目录"
            echo
            echo "Python 相关文件:"
            find "$ENV_PATH/bin" -name "python*" -type f 2>/dev/null || echo "在bin目录中未找到Python文件"
            echo
            
            # 检查每个Python文件的详情
            for python_file in "$ENV_PATH/bin/python"*; do
                if [[ -f "$python_file" ]]; then
                    echo "文件: $python_file"
                    echo "  权限: $(ls -l "$python_file" | awk '{print $1}')"
                    echo "  大小: $(ls -lh "$python_file" | awk '{print $5}')"
                    if [[ -x "$python_file" ]]; then
                        echo "  版本: $($python_file --version 2>&1 || echo '无法获取版本')"
                    else
                        echo "  版本: 文件不可执行"
                    fi
                    echo
                fi
            done
        else
            echo "无法获取环境路径"
        fi
    else
        echo "环境不存在: ✗"
        echo "建议运行: conda create -n ${CONDA_ENV} python=3.12"
    fi
    echo
    
    echo "=== Python 信息 ==="
    if command -v python &> /dev/null; then
        echo "系统 Python: $(which python)"
        echo "系统 Python 版本: $(python --version 2>&1)"
    else
        echo "系统中未找到 python 命令"
    fi
    
    if command -v python3 &> /dev/null; then
        echo "系统 Python3: $(which python3)"
        echo "系统 Python3 版本: $(python3 --version 2>&1)"
    else
        echo "系统中未找到 python3 命令"
    fi
    echo
    
    echo "=== 服务状态 ==="
    if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo "服务已安装: ✓"
        show_status
    else
        echo "服务未安装: ✗"
    fi
    echo
    
    echo "=== 权限检查 ==="
    echo "当前用户sudo权限:"
    if sudo -n true 2>/dev/null; then
        echo "  sudo 权限: ✓"
    else
        echo "  sudo 权限: ✗ (需要密码)"
    fi
    
    echo "目录权限:"
    for dir in "$INSTALL_DIR" "$LOG_DIR" "/etc/systemd/system"; do
        if [[ -d "$dir" ]]; then
            echo "  $dir: $(ls -ld "$dir" | awk '{print $1, $3, $4}')"
        else
            echo "  $dir: 不存在"
        fi
    done
    echo
    
    echo "=== 网络检查 ==="
    echo "端口监听:"
    netstat -tlnp 2>/dev/null | grep ":8000" || echo "  端口8000未监听"
    echo
    echo "服务连通性:"
    if curl -s --max-time 5 "http://localhost:8000/" &> /dev/null; then
        echo "  http://localhost:8000/: ✓"
    else
        echo "  http://localhost:8000/: ✗"
    fi
    
    echo "=== 诊断完成 ==="
}

# 主函数
main() {
    local uninstall=false
    local status=false
    local logs=false
    local debug=false
    
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
            -e|--env)
                CONDA_ENV="$2"
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
            --debug)
                debug=true
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
    elif [[ "$debug" == "true" ]]; then
        show_debug_info
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