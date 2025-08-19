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
    
    # STT Service Configuration
    stt_engine: str = Field(
        default="mock",
        description="STT引擎选择: 'mock', 'whisper', 'vosk'"
    )
    
    # Whisper STT Configuration
    use_whisper: bool = Field(
        default=False,
        description="是否使用Whisper STT服务"
    )
    whisper_model_name: str = Field(
        default="base",
        description="Whisper模型名称: tiny, base, small, medium, large, large-v2, large-v3, distil-large-v3"
    )
    whisper_model_path: str = Field(
        default="model/whisper-models",
        description="Whisper模型存储目录路径"
    )
    whisper_device: str = Field(
        default="cpu",
        description="Whisper推理设备: 'cpu', 'cuda', 'auto'"
    )
    whisper_compute_type: str = Field(
        default="int8",
        description="Whisper计算类型: 'float16', 'int8_float16', 'int8', 'float32'"
    )
    whisper_batch_size: int = Field(
        default=16,
        description="Whisper批处理大小"
    )
    whisper_beam_size: int = Field(
        default=5,
        description="Whisper束搜索大小"
    )
    whisper_language: Optional[str] = Field(
        default=None,
        description="强制指定语言（如'zh', 'en'），None为自动检测"
    )
    # VAD Filter: Automatically filter out silence
    whisper_vad_filter: bool = Field(
        default=True,
        description="Enable the VAD filter to remove silence from the audio."
    )

    # Progressive Transcription Buffer
    whisper_progressive_transcription_seconds: float = Field(
        default=1.0,
        description="Buffer duration in seconds for progressive transcription. Audio chunks are processed each time this duration is reached."
    )
    whisper_word_timestamps: bool = Field(
        default=False,
        description="是否启用词级时间戳"
    )
    whisper_temperature: float = Field(
        default=0.0,
        description="Whisper温度参数，0为确定性输出"
    )
    whisper_condition_on_previous_text: bool = Field(
        default=True,
        description="是否基于前一段文本进行条件化"
    )
    
    # Vosk STT Configuration (保留作为备用)
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
    websocket_timeout: int = Field(default=600, description="WebSocket连接超时时间")
    websocket_ping_interval: int = Field(default=30, description="WebSocket心跳间隔时间")
    websocket_ping_timeout: int = Field(default=10, description="WebSocket心跳超时时间")
    websocket_max_message_size: int = Field(default=16*1024*1024, description="WebSocket最大消息大小")
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
    audio_buffer_max_size: int = Field(default=50*1024*1024, description="音频缓冲区最大大小(50MB)")
    audio_buffer_cleanup_interval: int = Field(default=10, description="音频缓冲区清理间隔(秒)")
    audio_max_chunks_per_second: int = Field(default=100, description="每秒最大音频块数量(背压控制)")
    
    # Performance Configuration
    max_workers: int = Field(default=4, description="最大工作线程数")
    
    # Session Persistence Configuration
    session_persistence_enabled: bool = Field(default=True, description="是否启用会话持久化")
    session_persistence_dir: str = Field(default="./sessions", description="会话持久化存储目录")
    session_max_persistence_hours: int = Field(default=24, description="会话最大持久化时间(小时)")
    session_cleanup_interval_minutes: int = Field(default=60, description="会话清理间隔(分钟)")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# 全局配置实例
settings = Settings()