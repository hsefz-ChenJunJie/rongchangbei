# AI对话应用后端 Dockerfile
FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量，使用清华镜像源
ENV PYPI_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
ENV PIP_TRUSTED_HOST="pypi.tuna.tsinghua.edu.cn"

# 替换APT源为清华镜像源以提升下载速度
RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources

# 配置APT以加速下载
RUN echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/99timeout && \
    echo 'Acquire::ftp::Timeout "30";' >> /etc/apt/apt.conf.d/99timeout && \
    echo 'Acquire::Retries "3";' >> /etc/apt/apt.conf.d/99timeout && \
    echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf.d/99timeout && \
    echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf.d/99timeout

# 安装系统依赖（包括音频相关）
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    unzip \
    gcc \
    g++ \
    build-essential \
    pkg-config \
    libasound2-dev \
    portaudio19-dev \
    libportaudio2 \
    libportaudiocpp0 \
    ffmpeg \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv（快速的Python包管理器）
RUN pip install --no-cache-dir -i $PYPI_INDEX_URL uv

# 创建非root用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 复制requirements文件
COPY requirements.txt .

# 使用 uv 安装Python依赖，配置镜像源
# 先安装主要依赖
RUN uv pip install --system --no-cache -i $PYPI_INDEX_URL \
    fastapi==0.104.1 \
    uvicorn[standard]==0.24.0 \
    websockets==12.0 \
    pydantic==2.5.0 \
    pydantic-settings==2.1.0 \
    vosk==0.3.45 \
    openai==1.3.0 \
    httpx==0.25.2 \
    asyncio-mqtt==0.11.1 \
    wave==0.0.2 \
    python-multipart==0.0.6 \
    python-dotenv==1.0.0 \
    typing-extensions==4.8.0 \
    structlog==23.2.0

# 单独安装可能有问题的pyaudio
RUN uv pip install --system --no-cache -i $PYPI_INDEX_URL pyaudio>=0.2.11

# 安装测试依赖（可选）
RUN uv pip install --system --no-cache -i $PYPI_INDEX_URL \
    pytest==7.4.3 \
    pytest-asyncio==0.21.1

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p /app/logs /app/model

# 设置权限
RUN chown -R appuser:appuser /app
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# 暴露端口
EXPOSE 8000

# 设置环境变量
ENV PYTHONPATH=/app
ENV HOST=0.0.0.0
ENV PORT=8000

# 启动命令
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]