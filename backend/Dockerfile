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
    LC_ALL=C.UTF-8

# 配置apt镜像源（阿里云镜像）
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置工作目录
WORKDIR /app

# 创建uv缓存目录和应用目录
RUN mkdir -p /tmp/uv-cache /app/logs

# 配置pip镜像源并安装uv
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple/ && \
    pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn && \
    pip config set global.timeout 60 && \
    pip install --no-cache-dir uv

# 复制 requirements.txt（利用Docker层缓存）
COPY requirements.txt .

# 使用uv安装Python依赖（最大化缓存利用）
RUN --mount=type=cache,target=/tmp/uv-cache \
    uv pip install --system --index-url https://pypi.tuna.tsinghua.edu.cn/simple/ \
    --trusted-host pypi.tuna.tsinghua.edu.cn \
    -r requirements.txt && \
    rm -rf /tmp/pip-cache

# 创建非root用户（安全最佳实践）
RUN useradd --create-home --shell /bin/bash --uid 1000 app && \
    chown -R app:app /app /tmp/uv-cache

# 复制应用代码（放在最后以利用缓存）
COPY --chown=app:app app/ ./app/
COPY --chown=app:app config/ ./config/

# 切换到非root用户
USER app

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# 启动命令
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]