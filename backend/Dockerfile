# 使用 Python 3.12 官方镜像
FROM python:3.12-slim

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    # uv配置
    UV_CACHE_DIR=/tmp/uv-cache \
    UV_LINK_MODE=copy \
    # 中文环境支持
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # 时区设置
    TZ=Asia/Shanghai

# 配置apt镜像源（阿里云镜像）
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gcc \
    g++ \
    ca-certificates \
    # 时区数据包
    tzdata \
    # PortAudio依赖（pyaudio需要）
    portaudio19-dev \
    libasound2-dev \
    # 音频处理依赖
    libsndfile1-dev \
    ffmpeg \
    # Whisper模型转换和推理依赖
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置工作目录
WORKDIR /app

# 创建必要目录
RUN mkdir -p /tmp/uv-cache /app/logs /app/model/whisper-models /app/model/vosk-model

# 配置pip镜像源并安装uv（多镜像源回退策略）
RUN pip config set global.timeout 60 && \
    # 尝试清华镜像源
    (pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple/ --trusted-host pypi.tuna.tsinghua.edu.cn uv || \
    # 回退到阿里云镜像源
    pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com uv || \
    # 回退到豆瓣镜像源
    pip install --no-cache-dir -i https://pypi.douban.com/simple/ --trusted-host pypi.douban.com uv || \
    # 最后回退到官方源
    pip install --no-cache-dir uv)

# 复制 requirements.txt（利用Docker层缓存）
COPY requirements.txt .

# 使用uv安装Python依赖（多镜像源回退策略）
RUN --mount=type=cache,target=/tmp/uv-cache \
    # 尝试清华镜像源
    (uv pip install --system --index-url https://pypi.tuna.tsinghua.edu.cn/simple/ --trusted-host pypi.tuna.tsinghua.edu.cn -r requirements.txt || \
    # 回退到阿里云镜像源
    uv pip install --system --index-url https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt || \
    # 回退到豆瓣镜像源
    uv pip install --system --index-url https://pypi.douban.com/simple/ --trusted-host pypi.douban.com -r requirements.txt || \
    # 最后回退到官方源
    uv pip install --system -r requirements.txt) && \
    rm -rf /tmp/pip-cache

# 创建非root用户（安全最佳实践）
RUN useradd --create-home --shell /bin/bash --uid 1000 app && \
    chown -R app:app /app /tmp/uv-cache

# 复制应用代码（放在最后以利用缓存）
COPY --chown=app:app app/ ./app/
COPY --chown=app:app config/ ./config/
COPY --chown=app:app scripts/ ./scripts/

# 可选：复制.env文件（如果存在）
# 创建空的.env文件作为占位符，然后尝试复制真实的.env文件
RUN touch .env
COPY --chown=app:app .env* ./

# 切换到非root用户
USER app

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# 启动命令
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]