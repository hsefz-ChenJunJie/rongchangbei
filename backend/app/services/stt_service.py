"""
STT (Speech-to-Text) 服务 - 累积处理模式
"""
import asyncio
import base64
import logging
from typing import Dict, Optional, Any, List
from datetime import datetime, timedelta
import json
import time

from config.settings import settings

logger = logging.getLogger(__name__)


class STTService:
    """STT服务管理器 - 累积处理模式"""
    
    def __init__(self):
        self.is_initialized = False
        self.model = None
        self.active_streams: Dict[str, Dict[str, Any]] = {}
        self.cleanup_task = None
        
        # 缓冲区配置
        self.max_buffer_size = settings.audio_buffer_max_size
        
    async def initialize(self) -> bool:
        """
        初始化STT服务
        
        Returns:
            bool: 初始化是否成功
        """
        try:
            # TODO: 实际的Vosk初始化
            # 目前使用Mock模式
            logger.info("STT服务初始化（Mock模式）")
            
            # 模拟初始化延迟
            await asyncio.sleep(0.1)
            
            self.is_initialized = True
            
            logger.info("STT服务初始化完成（累积处理模式）")
            
            return True
            
        except Exception as e:
            logger.error(f"STT服务初始化失败: {e}")
            return False
    
    async def shutdown(self):
        """关闭STT服务"""
        try:
            # 停止所有活动流
            session_ids = list(self.active_streams.keys())
            for session_id in session_ids:
                await self.stop_stream_processing(session_id)
            
            self.is_initialized = False
            logger.info("STT服务已关闭")
            
        except Exception as e:
            logger.error(f"STT服务关闭时发生错误: {e}")
    
    async def start_stream_processing(self, session_id: str, existing_audio: bytes = None) -> bool:
        """
        开始音频流处理（支持断连恢复）
        
        Args:
            session_id: 会话ID
            existing_audio: 现有的音频数据（用于断连恢复）
            
        Returns:
            bool: 是否成功开始
        """
        if not self.is_initialized:
            logger.error("STT服务未初始化")
            return False
        
        if session_id in self.active_streams:
            logger.warning(f"会话 {session_id} 的音频流已在处理中，重置流状态")
            # 保留现有音频数据
            existing_stream = self.active_streams[session_id]
            existing_audio = existing_audio or b''.join(existing_stream.get("audio_chunks", []))
        
        try:
            # 创建流处理状态
            self.active_streams[session_id] = {
                "start_time": datetime.utcnow(),
                "audio_chunks": [existing_audio] if existing_audio else [],
                "total_bytes": len(existing_audio) if existing_audio else 0,
                "is_disconnection_recovery": existing_audio is not None
            }
            
            if existing_audio:
                logger.info(f"恢复音频流处理: {session_id}, 已有音频: {len(existing_audio)} 字节")
            else:
                logger.info(f"开始音频流处理: {session_id}")
            return True
            
        except Exception as e:
            logger.error(f"开始音频流处理失败 {session_id}: {e}")
            return False
    
    async def process_audio_chunk(self, session_id: str, audio_chunk_base64: str) -> Optional[Dict[str, Any]]:
        """
        处理音频数据块（累积模式）
        
        Args:
            session_id: 会话ID
            audio_chunk_base64: base64编码的音频数据
            
        Returns:
            Optional[Dict[str, Any]]: 如果缓冲区满，返回背压控制信息
        """
        if not self.is_initialized:
            logger.error("STT服务未初始化")
            return None
        
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流未开始")
            return None
        
        try:
            # 解码音频数据
            audio_data = base64.b64decode(audio_chunk_base64)
            
            # 获取流状态
            stream_info = self.active_streams[session_id]
            
            # 缓冲区大小检查
            new_total_bytes = stream_info["total_bytes"] + len(audio_data)
            if new_total_bytes > self.max_buffer_size:
                logger.warning(f"音频缓冲区已满 {session_id}: 当前 {stream_info['total_bytes']} 字节, 最大 {self.max_buffer_size} 字节")
                return {
                    "buffer_full": True,
                    "message": f"音频缓冲区已满 (当前: {stream_info['total_bytes']}, 最大: {self.max_buffer_size})"
                }
            
            # 累积音频数据
            stream_info["audio_chunks"].append(audio_data)
            stream_info["total_bytes"] += len(audio_data)
            
            logger.debug(f"累积音频块 {session_id}: 数据长度 {len(audio_data)}, 总长度 {stream_info['total_bytes']}")
            return None  # 累积模式下，不返回部分结果
                
        except Exception as e:
            logger.error(f"处理音频块失败 {session_id}: {e}")
            return None
    
    async def stop_stream_processing(self, session_id: str) -> bool:
        """
        停止音频流处理
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 是否成功停止
        """
        if session_id not in self.active_streams:
            logger.warning(f"会话 {session_id} 的音频流不存在")
            return True
        
        try:
            stream_info = self.active_streams[session_id]
            
            # TODO: 停止Vosk处理
            
            logger.info(f"停止音频流处理: {session_id}, 总字节数: {stream_info['total_bytes']}")
            
            return True
            
        except Exception as e:
            logger.error(f"停止音频流处理失败 {session_id}: {e}")
            return False
    
    async def get_final_transcription(self, session_id: str) -> Optional[str]:
        """
        获取最终转录结果（累积处理模式）
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[str]: 最终转录文本
        """
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流不存在")
            return None
        
        try:
            stream_info = self.active_streams[session_id]
            
            # 合并所有音频块
            all_audio = b''.join(stream_info["audio_chunks"])
            total_bytes = len(all_audio)
            
            logger.info(f"开始一次性处理累积音频: {session_id}, 总字节数: {total_bytes}")
            
            # TODO: 使用实际的STT服务处理合并的音频
            # 目前返回Mock结果
            
            if total_bytes > 0:
                # 模拟处理时间（基于音频大小）
                processing_time = min(0.1 + total_bytes / 100000, 2.0)  # 最多2秒
                await asyncio.sleep(processing_time)
                
                final_text = f"这是累积转录文本，处理了 {total_bytes} 字节的音频数据"
                
                # 如果是断连恢复，添加标记
                if stream_info.get("is_disconnection_recovery"):
                    final_text = f"[恢复] {final_text}"
            else:
                final_text = "未检测到音频内容"
            
            # 清理流状态
            del self.active_streams[session_id]
            
            logger.info(f"累积转录完成 {session_id}: {final_text[:100]}...")
            
            return final_text
            
        except Exception as e:
            logger.error(f"获取最终转录失败 {session_id}: {e}")
            return None
    
    def get_accumulated_audio(self, session_id: str) -> Optional[bytes]:
        """
        获取已累积的音频数据（用于断连恢复）
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[bytes]: 累积的音频数据
        """
        if session_id not in self.active_streams:
            return None
        
        try:
            stream_info = self.active_streams[session_id]
            all_audio = b''.join(stream_info["audio_chunks"])
            logger.info(f"获取累积音频数据: {session_id}, 大小: {len(all_audio)} 字节")
            return all_audio
        except Exception as e:
            logger.error(f"获取累积音频数据失败 {session_id}: {e}")
            return None
    
    
    def get_stream_status(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        获取音频流状态
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[Dict[str, Any]]: 流状态信息
        """
        if session_id not in self.active_streams:
            return None
        
        stream_info = self.active_streams[session_id]
        
        return {
            "session_id": session_id,
            "start_time": stream_info["start_time"].isoformat(),
            "chunk_count": len(stream_info["audio_chunks"]),
            "total_bytes": stream_info["total_bytes"],
            "duration_seconds": (datetime.utcnow() - stream_info["start_time"]).total_seconds(),
            "buffer_usage_percent": round((stream_info["total_bytes"] / self.max_buffer_size) * 100, 2),
            "is_disconnection_recovery": stream_info.get("is_disconnection_recovery", False)
        }
    
    def get_all_stream_status(self) -> List[Dict[str, Any]]:
        """
        获取所有活动流的状态
        
        Returns:
            List[Dict[str, Any]]: 所有流状态列表
        """
        statuses = []
        for session_id in self.active_streams:
            status = self.get_stream_status(session_id)
            if status:
                statuses.append(status)
        
        return statuses
    
    def is_stream_active(self, session_id: str) -> bool:
        """
        检查音频流是否活动
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 流是否活动
        """
        return session_id in self.active_streams
    
    async def health_check(self) -> Dict[str, Any]:
        """
        健康检查
        
        Returns:
            Dict[str, Any]: 健康状态信息
        """
        total_buffer_usage = sum(stream["total_bytes"] for stream in self.active_streams.values())
        
        return {
            "service": "STT",
            "status": "healthy" if self.is_initialized else "unhealthy",
            "initialized": self.is_initialized,
            "active_streams": len(self.active_streams),
            "model_path": settings.vosk_model_path,
            "sample_rate": settings.vosk_sample_rate,
            "mode": "mock_cumulative",  # 标识当前为Mock累积模式
            "buffer_config": {
                "max_buffer_size": self.max_buffer_size
            },
            "buffer_usage": {
                "total_bytes": total_buffer_usage,
                "usage_percent": round((total_buffer_usage / self.max_buffer_size) * 100, 2) if self.max_buffer_size > 0 else 0
            }
        }


# ===============================
# Whisper STT服务实现
# ===============================

class WhisperSTTService(STTService):
    """
    基于faster-whisper的STT服务实现 - 累积处理模式
    
    注意：需要安装faster-whisper库
    pip install faster-whisper
    """
    
    def __init__(self):
        super().__init__()
        self.model = None
        self.model_info = {}
        
    async def initialize(self) -> bool:
        """
        初始化Whisper服务
        """
        try:
            from faster_whisper import WhisperModel
            import os
            import torch
            
            # 自动检测设备
            device = self._detect_device() if settings.whisper_device == "auto" else settings.whisper_device
            
            # 确定计算类型
            compute_type = self._get_compute_type(device)
            
            # 构建模型路径
            model_path = self._get_model_path()
            
            logger.info(f"初始化Whisper服务: 模型={settings.whisper_model_name}, 设备={device}, 计算类型={compute_type}")
            logger.info(f"模型路径: {model_path}")
            
            # 检查本地模型文件
            if os.path.exists(model_path):
                logger.info(f"从本地加载Whisper模型: {model_path}")
                self.model = WhisperModel(
                    model_path,
                    device=device,
                    compute_type=compute_type,
                    cpu_threads=settings.max_workers
                )
            else:
                logger.error(f"Whisper模型文件不存在: {model_path}")
                logger.info("请确保已将模型文件下载到指定目录，或使用模型转换工具")
                return False
            
            # 存储模型信息
            self.model_info = {
                "model_name": settings.whisper_model_name,
                "model_path": model_path,
                "device": device,
                "compute_type": compute_type,
                "batch_size": settings.whisper_batch_size,
                "beam_size": settings.whisper_beam_size,
                "language": settings.whisper_language,
                "vad_filter": settings.whisper_vad_filter
            }
            
            self.is_initialized = True
            
            logger.info("Whisper STT服务初始化完成（累积处理模式）")
            return True
            
        except ImportError:
            logger.error("faster-whisper库未安装，请运行: pip install faster-whisper")
            return False
        except Exception as e:
            logger.error(f"Whisper STT服务初始化失败: {e}")
            return False
    
    def _detect_device(self) -> str:
        """
        自动检测最佳推理设备
        """
        try:
            import torch
            if torch.cuda.is_available():
                logger.info("检测到CUDA支持，使用GPU推理")
                return "cuda"
            else:
                logger.info("未检测到CUDA支持，使用CPU推理")
                return "cpu"
        except ImportError:
            logger.info("PyTorch未安装，使用CPU推理")
            return "cpu"
    
    def _get_compute_type(self, device: str) -> str:
        """
        根据设备选择合适的计算类型
        """
        if device == "cuda":
            # GPU推理：优先使用int8_float16以节省显存
            if settings.whisper_compute_type in ["float16", "int8_float16"]:
                return settings.whisper_compute_type
            else:
                logger.warning(f"GPU设备不支持计算类型 {settings.whisper_compute_type}，使用 int8_float16")
                return "int8_float16"
        else:
            # CPU推理：使用int8或float32
            if settings.whisper_compute_type in ["int8", "float32"]:
                return settings.whisper_compute_type
            else:
                logger.warning(f"CPU设备不支持计算类型 {settings.whisper_compute_type}，使用 int8")
                return "int8"
    
    def _get_model_path(self) -> str:
        """
        构建模型文件路径
        """
        import os
        
        # 检查是否是预转换的CT2模型目录
        ct2_model_path = os.path.join(settings.whisper_model_path, f"{settings.whisper_model_name}-ct2")
        if os.path.exists(ct2_model_path):
            return ct2_model_path
        
        # 检查标准模型文件
        standard_model_path = os.path.join(settings.whisper_model_path, settings.whisper_model_name)
        if os.path.exists(standard_model_path):
            return standard_model_path
        
        # 如果都不存在，返回CT2路径（用于错误提示）
        return ct2_model_path
    
    async def start_stream_processing(self, session_id: str, existing_audio: bytes = None) -> bool:
        """
        开始Whisper音频流处理（累积模式）
        """
        if not self.is_initialized:
            logger.error("Whisper服务未初始化")
            return False

        if session_id in self.active_streams:
            logger.warning(f"会话 {session_id} 的音频流已在处理中，重置流状态")
            # 保留现有音频数据
            existing_stream = self.active_streams[session_id]
            existing_audio = existing_audio or b''.join(existing_stream.get("audio_chunks", []))

        try:
            # 创建流处理状态
            self.active_streams[session_id] = {
                "start_time": datetime.utcnow(),
                "audio_chunks": [existing_audio] if existing_audio else [],
                "total_bytes": len(existing_audio) if existing_audio else 0,
                "is_disconnection_recovery": existing_audio is not None
            }
            
            if existing_audio:
                logger.info(f"恢复Whisper音频流处理: {session_id}, 已有音频: {len(existing_audio)} 字节")
            else:
                logger.info(f"开始Whisper累积音频流处理: {session_id}")
            return True
            
        except Exception as e:
            logger.error(f"开始Whisper流处理失败 {session_id}: {e}")
            return False
    
    async def process_audio_chunk(self, session_id: str, audio_chunk_base64: str) -> Optional[Dict[str, Any]]:
        """
        处理音频数据块（累积模式）
        """
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流未开始")
            return None

        try:
            audio_data = base64.b64decode(audio_chunk_base64)
            stream_info = self.active_streams[session_id]

            # 缓冲区大小检查
            new_total_bytes = stream_info["total_bytes"] + len(audio_data)
            if new_total_bytes > self.max_buffer_size:
                logger.warning(f"Whisper音频缓冲区已满 {session_id}: 当前 {stream_info['total_bytes']} 字节")
                return {
                    "buffer_full": True,
                    "message": f"音频缓冲区已满 (当前: {stream_info['total_bytes']}, 最大: {self.max_buffer_size})"
                }

            # 累积音频数据
            stream_info["audio_chunks"].append(audio_data)
            stream_info["total_bytes"] += len(audio_data)

            logger.debug(f"Whisper累积音频块 {session_id}: 数据长度 {len(audio_data)}, 总长度 {stream_info['total_bytes']}")
            return None  # 累积模式下，不返回部分结果

        except Exception as e:
            logger.error(f"Whisper处理音频块失败 {session_id}: {e}")
            return None

    async def get_final_transcription(self, session_id: str) -> Optional[str]:
        """
        获取Whisper最终转录结果（累积模式）
        """
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流不存在")
            return None

        try:
            stream_info = self.active_streams[session_id]
            
            # 合并所有音频块
            all_audio = b''.join(stream_info["audio_chunks"])
            total_bytes = len(all_audio)
            
            logger.info(f"开始一次性Whisper转录: {session_id}, 总字节数: {total_bytes}")

            if total_bytes > 0:
                # 执行转录
                segments, _ = await self._transcribe_audio_bytes(all_audio)
                
                if segments:
                    final_text = "".join([segment.text.strip() for segment in segments])
                    
                    # 如果是断连恢复，添加标记
                    if stream_info.get("is_disconnection_recovery"):
                        final_text = f"[恢复] {final_text}"
                else:
                    final_text = "Whisper未识别到语音内容"
            else:
                final_text = "未检测到音频内容"
                
            logger.info(f"Whisper累积转录完成 {session_id}: {final_text[:100]}...")
            return final_text

        except Exception as e:
            logger.error(f"Whisper获取最终转录失败 {session_id}: {e}")
            return None
        finally:
            # 确保清理流状态
            if session_id in self.active_streams:
                del self.active_streams[session_id]
                logger.debug(f"已清理Whisper会话流: {session_id}")
    
    async def _transcribe_audio_bytes(self, audio_bytes: bytes):
        """
        执行Whisper音频转录（从字节数据）
        """
        import tempfile
        import wave
        import os
        import asyncio

        if not audio_bytes:
            return [], None

        try:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_audio_file:
                temp_audio_path = temp_audio_file.name
                with wave.open(temp_audio_path, 'wb') as wav_file:
                    wav_file.setnchannels(settings.audio_channels)
                    wav_file.setsampwidth(2)  # 16-bit
                    wav_file.setframerate(settings.audio_sample_rate)
                    wav_file.writeframes(audio_bytes)

            def _sync_transcribe():
                return self.model.transcribe(
                    temp_audio_path,
                    beam_size=settings.whisper_beam_size,
                    language=settings.whisper_language,
                    temperature=settings.whisper_temperature,
                    condition_on_previous_text=settings.whisper_condition_on_previous_text,
                    vad_filter=settings.whisper_vad_filter,
                    word_timestamps=settings.whisper_word_timestamps
                )

            loop = asyncio.get_event_loop()
            segments, info = await loop.run_in_executor(None, _sync_transcribe)
            return segments, info

        finally:
            if 'temp_audio_path' in locals() and os.path.exists(temp_audio_path):
                os.unlink(temp_audio_path)
    
    async def health_check(self) -> Dict[str, Any]:
        """
        Whisper健康检查
        """
        base_status = await super().health_check()
        base_status.update({
            "mode": "whisper_cumulative",
            "model_info": self.model_info,
            "model_loaded": self.model is not None
        })
        return base_status


# ===============================
# Vosk集成代码（保留作为备用）
# ===============================

class VoskSTTService(STTService):
    """
    真实的Vosk STT服务实现 - 累积处理模式
    
    注意：需要安装vosk库和下载模型文件
    pip install vosk
    """
    
    def __init__(self):
        super().__init__()
    
    async def initialize(self) -> bool:
        """
        初始化真实的Vosk服务
        """
        try:
            import vosk
            import json
            import os
            
            # 检查模型文件
            if not os.path.exists(settings.vosk_model_path):
                logger.error(f"Vosk模型文件不存在: {settings.vosk_model_path}")
                return False
            
            # 加载模型
            self.model = vosk.Model(settings.vosk_model_path)
            
            self.is_initialized = True
            logger.info(f"Vosk STT服务初始化完成（累积处理模式），模型路径: {settings.vosk_model_path}")
            
            return True
            
        except ImportError:
            logger.error("Vosk库未安装，请运行: pip install vosk")
            return False
        except Exception as e:
            logger.error(f"Vosk STT服务初始化失败: {e}")
            return False
    
    async def get_final_transcription(self, session_id: str) -> Optional[str]:
        """获取Vosk最终转录结果（累积模式）"""
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流不存在")
            return None
        
        try:
            import vosk
            import json
            
            stream_info = self.active_streams[session_id]
            
            # 合并所有音频块
            all_audio = b''.join(stream_info["audio_chunks"])
            total_bytes = len(all_audio)
            
            logger.info(f"开始一次性Vosk转录: {session_id}, 总字节数: {total_bytes}")
            
            if total_bytes > 0:
                # 创建识别器
                recognizer = vosk.KaldiRecognizer(self.model, settings.vosk_sample_rate)
                recognizer.SetWords(True)
                
                # 处理所有音频数据
                if recognizer.AcceptWaveform(all_audio):
                    result = json.loads(recognizer.Result())
                    final_text = result.get("text", "")
                else:
                    final_result = json.loads(recognizer.FinalResult())
                    final_text = final_result.get("text", "")
                
                # 如果是断连恢复，添加标记
                if stream_info.get("is_disconnection_recovery"):
                    final_text = f"[恢复] {final_text}" if final_text else "[恢复] 未识别到语音"
                elif not final_text:
                    final_text = "Vosk未识别到语音内容"
            else:
                final_text = "未检测到音频内容"
            
            logger.info(f"Vosk累积转录完成 {session_id}: {final_text}")
            return final_text
            
        except Exception as e:
            logger.error(f"获取Vosk最终转录失败 {session_id}: {e}")
            return None
        finally:
            # 确保清理流状态
            if session_id in self.active_streams:
                del self.active_streams[session_id]
                logger.debug(f"已清理Vosk会话流: {session_id}")
    
    async def health_check(self) -> Dict[str, Any]:
        """Vosk健康检查"""
        base_status = await super().health_check()
        base_status.update({
            "mode": "vosk_cumulative"
        })
        return base_status


# 根据配置选择使用哪个实现
def create_stt_service() -> STTService:
    """
    创建STT服务实例
    
    Returns:
        STTService: STT服务实例
    """
    # 优先使用stt_engine配置
    engine = settings.stt_engine.lower()
    
    # 向后兼容：检查旧配置
    if engine == "mock":
        if settings.use_whisper:
            engine = "whisper"
        elif settings.use_real_vosk:
            engine = "vosk"
    
    logger.info(f"STT服务配置: engine={engine}")
    
    if engine == "whisper":
        logger.info("使用Whisper STT服务")
        return WhisperSTTService()
    elif engine == "vosk":
        logger.info("使用Vosk STT服务")
        return VoskSTTService()
    else:
        logger.info("使用Mock STT服务")
        return STTService()  # Mock版本