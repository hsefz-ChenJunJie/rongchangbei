"""
应用配置模块
"""
from pydantic import Field
from pydantic_settings import BaseSettings
from typing import Optional, List


class Settings(BaseSettings):
    """应用配置类"""
    
    # OpenRouter LLM API Configuration
    openrouter_api_key: Optional[str] = Field(default=None, description="OpenRouter API密钥")
    openrouter_base_url: str = Field(
        default="https://openrouter.ai/api/v1",
        description="OpenRouter API基础URL"
    )
    openrouter_model: str = Field(
        default="anthropic/claude-3-haiku",
        description="OpenRouter使用的模型名称"
    )
    openrouter_temperature: float = Field(
        default=0.7,
        description="OpenRouter模型温度参数"
    )
    openrouter_max_tokens: int = Field(
        default=800,
        description="OpenRouter最大token数"
    )
    
    # Vosk STT Configuration
    use_real_vosk: bool = Field(
        default=False,
        description="是否使用真实的Vosk STT服务"
    )
    vosk_model_path: str = Field(
        default="model/vosk-model",
        description="Vosk STT模型路径"
    )
    vosk_sample_rate: int = Field(
        default=16000,
        description="Vosk音频采样率"
    )
    
    # Server Configuration
    host: str = Field(default="127.0.0.1", description="服务器主机地址")
    port: int = Field(default=8000, description="服务器端口")
    debug: bool = Field(default=True, description="调试模式")
    allowed_origins: List[str] = Field(
        default=["*"], 
        description="CORS允许的域名列表"
    )
    
    # Timeout Settings (seconds)
    stt_timeout: int = Field(default=30, description="STT服务超时时间")
    llm_timeout: int = Field(default=30, description="LLM服务超时时间")
    websocket_timeout: int = Field(default=300, description="WebSocket连接超时时间")
    timeout: int = Field(default=60, description="通用超时时间")
    
    # Logging Configuration
    log_level: str = Field(default="INFO", description="日志级别")
    log_format: str = Field(default="json", description="日志格式")
    log_file: str = Field(default="logs/app.log", description="日志文件路径")
    log_max_size: str = Field(default="100MB", description="日志文件最大大小")
    log_backup_count: int = Field(default=5, description="日志备份文件数量")
    
    # Audio Processing
    audio_chunk_size: int = Field(default=4096, description="音频数据块大小")
    audio_sample_rate: int = Field(default=16000, description="音频采样率")
    audio_channels: int = Field(default=1, description="音频声道数")
    
    # Performance Configuration
    max_workers: int = Field(default=4, description="最大工作线程数")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# 全局配置实例
settings = Settings()