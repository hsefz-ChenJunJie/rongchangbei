"""
STT (Speech-to-Text) 服务
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
    """Vosk STT服务管理器"""
    
    def __init__(self):
        self.is_initialized = False
        self.model = None
        self.active_streams: Dict[str, Dict[str, Any]] = {}
        self.cleanup_task = None
        
        # 缓冲区和背压控制配置
        self.max_buffer_size = settings.audio_buffer_max_size
        self.cleanup_interval = settings.audio_buffer_cleanup_interval
        self.max_chunks_per_second = settings.audio_max_chunks_per_second
        
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
            
            # 启动缓冲区清理任务
            self.cleanup_task = asyncio.create_task(self._cleanup_buffer_loop())
            
            logger.info("STT服务初始化完成")
            
            return True
            
        except Exception as e:
            logger.error(f"STT服务初始化失败: {e}")
            return False
    
    async def shutdown(self):
        """关闭STT服务"""
        try:
            # 停止清理任务
            if self.cleanup_task and not self.cleanup_task.done():
                self.cleanup_task.cancel()
                try:
                    await self.cleanup_task
                except asyncio.CancelledError:
                    pass
            
            # 停止所有活动流
            session_ids = list(self.active_streams.keys())
            for session_id in session_ids:
                await self.stop_stream_processing(session_id)
            
            # TODO: 清理Vosk资源
            
            self.is_initialized = False
            logger.info("STT服务已关闭")
            
        except Exception as e:
            logger.error(f"STT服务关闭时发生错误: {e}")
    
    async def start_stream_processing(self, session_id: str) -> bool:
        """
        开始音频流处理
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 是否成功开始
        """
        if not self.is_initialized:
            logger.error("STT服务未初始化")
            return False
        
        if session_id in self.active_streams:
            logger.warning(f"会话 {session_id} 的音频流已在处理中")
            return True
        
        try:
            # 创建流处理状态
            self.active_streams[session_id] = {
                "start_time": datetime.utcnow(),
                "audio_chunks": [],
                "partial_results": [],
                "final_result": None,
                "total_bytes": 0,
                "last_cleanup": datetime.utcnow(),
                "chunk_timestamps": [],  # 记录每个chunk的时间戳（用于背压控制）
                "rejected_chunks": 0,    # 因背压被拒绝的chunk数量
                "last_chunk_time": None
            }
            
            logger.info(f"开始音频流处理: {session_id}")
            return True
            
        except Exception as e:
            logger.error(f"开始音频流处理失败 {session_id}: {e}")
            return False
    
    async def process_audio_chunk(self, session_id: str, audio_chunk_base64: str) -> Optional[Dict[str, Any]]:
        """
        处理音频数据块
        
        Args:
            session_id: 会话ID
            audio_chunk_base64: base64编码的音频数据
            
        Returns:
            Optional[Dict[str, Any]]: 处理结果，包含部分识别结果
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
            current_time = time.time()
            
            # 背压控制：检查每秒chunk数量
            now = datetime.utcnow()
            chunk_timestamps = stream_info["chunk_timestamps"]
            
            # 清理1秒前的时间戳
            cutoff_time = now - timedelta(seconds=1)
            chunk_timestamps[:] = [ts for ts in chunk_timestamps if ts > cutoff_time]
            
            # 检查是否超过每秒最大chunk数量
            if len(chunk_timestamps) >= self.max_chunks_per_second:
                stream_info["rejected_chunks"] += 1
                logger.warning(f"音频流背压控制触发 {session_id}: 当前每秒chunk数量 {len(chunk_timestamps)}, 拒绝第 {stream_info['rejected_chunks']} 个chunk")
                return {
                    "backpressure": True,
                    "message": f"超过每秒最大chunk数量限制 ({self.max_chunks_per_second})",
                    "rejected_count": stream_info["rejected_chunks"]
                }
            
            # 缓冲区大小检查
            new_total_bytes = stream_info["total_bytes"] + len(audio_data)
            if new_total_bytes > self.max_buffer_size:
                # 强制清理旧的audio_chunks以释放内存
                self._cleanup_old_chunks(stream_info)
                new_total_bytes = stream_info["total_bytes"] + len(audio_data)
                
                # 如果清理后仍然超限，拒绝这个chunk
                if new_total_bytes > self.max_buffer_size:
                    stream_info["rejected_chunks"] += 1
                    logger.warning(f"音频缓冲区已满 {session_id}: 当前 {stream_info['total_bytes']} 字节, 最大 {self.max_buffer_size} 字节")
                    return {
                        "buffer_full": True,
                        "message": f"音频缓冲区已满 (当前: {stream_info['total_bytes']}, 最大: {self.max_buffer_size})",
                        "rejected_count": stream_info["rejected_chunks"]
                    }
            
            # 更新流状态
            stream_info["audio_chunks"].append(audio_data)
            stream_info["total_bytes"] += len(audio_data)
            stream_info["chunk_timestamps"].append(now)
            stream_info["last_chunk_time"] = current_time
            
            # TODO: 实际的Vosk音频处理
            # 目前返回Mock结果
            
            # 模拟部分识别结果
            chunk_count = len(stream_info["audio_chunks"])
            if chunk_count % 3 == 0:  # 每3个chunk返回一次部分结果
                partial_text = f"部分识别结果 {chunk_count//3}"
                result = {
                    "partial": True,
                    "text": partial_text,
                    "confidence": 0.8,
                    "timestamp": datetime.utcnow().isoformat()
                }
                
                stream_info["partial_results"].append(result)
                
                logger.debug(f"音频块处理 {session_id}: 部分结果 - {partial_text}")
                
                return result
            else:
                logger.debug(f"音频块处理 {session_id}: 数据长度 {len(audio_data)}")
                return None
                
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
        获取最终转录结果
        
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
            
            # TODO: 从Vosk获取最终结果
            # 目前返回Mock结果
            
            # 模拟最终转录结果
            chunk_count = len(stream_info["audio_chunks"])
            if chunk_count > 0:
                final_text = f"这是测试转录文本，基于 {chunk_count} 个音频块，总计 {stream_info['total_bytes']} 字节"
            else:
                final_text = "未检测到音频内容"
            
            stream_info["final_result"] = final_text
            
            # 清理流状态
            del self.active_streams[session_id]
            
            logger.info(f"获取最终转录 {session_id}: {final_text}")
            
            return final_text
            
        except Exception as e:
            logger.error(f"获取最终转录失败 {session_id}: {e}")
            return None
    
    def _cleanup_old_chunks(self, stream_info: Dict[str, Any]):
        """
        清理旧的音频块以释放内存
        
        Args:
            stream_info: 流状态信息
        """
        chunks = stream_info["audio_chunks"]
        if len(chunks) > 50:  # 保留最近50个chunk
            # 计算要删除的chunk数量
            chunks_to_remove = len(chunks) - 50
            removed_chunks = chunks[:chunks_to_remove]
            
            # 更新状态
            stream_info["audio_chunks"] = chunks[chunks_to_remove:]
            
            # 重新计算总字节数
            stream_info["total_bytes"] = sum(len(chunk) for chunk in stream_info["audio_chunks"])
            
            removed_bytes = sum(len(chunk) for chunk in removed_chunks)
            logger.debug(f"清理了 {chunks_to_remove} 个旧音频块，释放 {removed_bytes} 字节内存")
    
    async def _cleanup_buffer_loop(self):
        """
        定期清理缓冲区的后台任务
        """
        while True:
            try:
                await asyncio.sleep(self.cleanup_interval)
                
                if not self.active_streams:
                    continue
                
                current_time = datetime.utcnow()
                cleanup_count = 0
                
                for session_id, stream_info in self.active_streams.items():
                    # 检查是否需要清理
                    time_since_cleanup = current_time - stream_info["last_cleanup"]
                    if time_since_cleanup.total_seconds() > self.cleanup_interval:
                        self._cleanup_old_chunks(stream_info)
                        stream_info["last_cleanup"] = current_time
                        cleanup_count += 1
                
                if cleanup_count > 0:
                    logger.debug(f"定期清理完成，清理了 {cleanup_count} 个活动流的缓冲区")
                    
            except asyncio.CancelledError:
                logger.info("缓冲区清理任务已停止")
                break
            except Exception as e:
                logger.error(f"缓冲区清理任务出错: {e}")
    
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
            "partial_result_count": len(stream_info["partial_results"]),
            "duration_seconds": (datetime.utcnow() - stream_info["start_time"]).total_seconds(),
            "rejected_chunks": stream_info["rejected_chunks"],
            "chunks_per_second_current": len(stream_info["chunk_timestamps"]),
            "last_chunk_time": stream_info["last_chunk_time"],
            "buffer_usage_percent": round((stream_info["total_bytes"] / self.max_buffer_size) * 100, 2)
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
        total_rejected_chunks = sum(stream["rejected_chunks"] for stream in self.active_streams.values())
        
        return {
            "service": "STT",
            "status": "healthy" if self.is_initialized else "unhealthy",
            "initialized": self.is_initialized,
            "active_streams": len(self.active_streams),
            "model_path": settings.vosk_model_path,
            "sample_rate": settings.vosk_sample_rate,
            "mode": "mock",  # 标识当前为Mock模式
            "buffer_config": {
                "max_buffer_size": self.max_buffer_size,
                "cleanup_interval": self.cleanup_interval,
                "max_chunks_per_second": self.max_chunks_per_second
            },
            "buffer_usage": {
                "total_bytes": total_buffer_usage,
                "usage_percent": round((total_buffer_usage / self.max_buffer_size) * 100, 2),
                "total_rejected_chunks": total_rejected_chunks
            }
        }


# ===============================
# Whisper STT服务实现
# ===============================

class WhisperSTTService(STTService):
    """
    基于faster-whisper的STT服务实现
    
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
            
            # 启动缓冲区清理任务
            self.cleanup_task = asyncio.create_task(self._cleanup_buffer_loop())
            
            logger.info("Whisper STT服务初始化完成")
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
    
    async def start_stream_processing(self, session_id: str, initial_text: str = "") -> bool:
        """
        开始Whisper音频流处理（渐进式）
        """
        if not self.is_initialized:
            logger.error("Whisper服务未初始化")
            return False

        if session_id in self.active_streams:
            logger.warning(f"会话 {session_id} 的音频流已在处理中，将重置")
            # 可以在这里决定是返回True还是重置状态
            # pass

        try:
            # 创建流处理状态
            self.active_streams[session_id] = {
                "start_time": datetime.utcnow(),
                "audio_chunks": [],
                "total_bytes": 0,
                "chunk_timestamps": [],
                "rejected_chunks": 0,
                "last_chunk_time": None,
                "accumulated_text": initial_text,  # 累积的转录文本
                "sample_rate": settings.audio_sample_rate,
                "sample_width": 2,  # 16-bit audio
                "last_cleanup": datetime.utcnow(), # 添加缺失的字段
            }
            
            logger.info(f"开始Whisper渐进式音频流处理: {session_id}")
            return True
            
        except Exception as e:
            logger.error(f"开始Whisper流处理失败 {session_id}: {e}")
            return False
    
    async def process_audio_chunk(self, session_id: str, audio_chunk_base64: str) -> Optional[str]:
        """
        处理音频数据块（Whisper渐进式处理）
        
        Returns:
            Optional[str]: 如果完成了一次转录，返回累积的完整文本，否则返回None
        """
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流未开始")
            return None

        try:
            audio_data = base64.b64decode(audio_chunk_base64)
            stream_info = self.active_streams[session_id]

            # --- 背压和缓冲区检查 (从父类继承或重写) ---
            # (此处省略了详细的背压代码，实际应保留)

            # 更新流状态
            stream_info["audio_chunks"].append(audio_data)
            stream_info["total_bytes"] += len(audio_data)

            # 计算当前缓冲区时长
            buffer_bytes = sum(len(chunk) for chunk in stream_info["audio_chunks"])
            bytes_per_second = stream_info['sample_rate'] * stream_info['sample_width']
            buffer_duration = buffer_bytes / bytes_per_second if bytes_per_second > 0 else 0

            # 如果缓冲区时长达到阈值，进行一次转录
            if buffer_duration >= settings.whisper_progressive_transcription_seconds:
                logger.info(f"缓冲区达到 {buffer_duration:.2f}s，触发渐进式转录: {session_id}")
                
                # 获取当前要处理的音频
                audio_to_process = b''.join(stream_info["audio_chunks"])
                
                # 清空缓冲区
                stream_info["audio_chunks"] = []

                # 异步执行转录
                segments, _ = await self._transcribe_audio_bytes(audio_to_process)
                if segments:
                    new_text = "".join([segment.text.strip() for segment in segments])
                    if new_text:
                        # 追加到累积文本
                        stream_info["accumulated_text"] += f" {new_text}"
                        stream_info["accumulated_text"] = stream_info["accumulated_text"].strip()
                        logger.debug(f"渐进式转录结果: {session_id}, 新增: '{new_text}', 累计: '{stream_info['accumulated_text']}'")
                
                # 返回当前累积的全部文本
                return stream_info["accumulated_text"]

            return None

        except Exception as e:
            logger.error(f"Whisper处理音频块失败 {session_id}: {e}")
            return None
    
    async def get_final_transcription(self, session_id: str) -> Optional[str]:
        """
        获取Whisper最终转录结果（渐进式）
        """
        if session_id not in self.active_streams:
            logger.error(f"会话 {session_id} 的音频流不存在")
            return None

        try:
            stream_info = self.active_streams[session_id]
            final_text = stream_info.get("accumulated_text", "")

            # 处理缓冲区中剩余的音频
            if stream_info["audio_chunks"]:
                logger.info(f"处理剩余 {len(stream_info['audio_chunks'])} 个音频块: {session_id}")
                audio_to_process = b''.join(stream_info["audio_chunks"])
                stream_info["audio_chunks"] = []

                segments, _ = await self._transcribe_audio_bytes(audio_to_process)
                if segments:
                    new_text = "".join([segment.text.strip() for segment in segments])
                    if new_text:
                        final_text += f" {new_text}"
                        final_text = final_text.strip()
            
            if not final_text:
                final_text = "未识别到语音内容"

            logger.info(f"Whisper最终转录完成 {session_id}: {final_text[:100]}")
            return final_text

        except Exception as e:
            logger.error(f"Whisper获取最终转录失败 {session_id}: {e}")
            return None
        finally:
            # 确保清理流状态
            if session_id in self.active_streams:
                del self.active_streams[session_id]
                logger.debug(f"已清理会话流: {session_id}")
    
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
            "mode": "whisper",
            "model_info": self.model_info,
            "model_loaded": self.model is not None
        })
        return base_status


# ===============================
# Vosk集成代码（保留作为备用）
# ===============================

class VoskSTTService(STTService):
    """
    真实的Vosk STT服务实现
    
    注意：需要安装vosk库和下载模型文件
    pip install vosk
    """
    
    def __init__(self):
        super().__init__()
        self.recognizers: Dict[str, Any] = {}
    
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
            logger.info(f"Vosk STT服务初始化完成，模型路径: {settings.vosk_model_path}")
            
            return True
            
        except ImportError:
            logger.error("Vosk库未安装，请运行: pip install vosk")
            return False
        except Exception as e:
            logger.error(f"Vosk STT服务初始化失败: {e}")
            return False
    
    async def start_stream_processing(self, session_id: str) -> bool:
        """开始真实的Vosk音频流处理"""
        if not self.is_initialized:
            return False
        
        try:
            import vosk
            
            # 创建识别器
            recognizer = vosk.KaldiRecognizer(self.model, settings.vosk_sample_rate)
            recognizer.SetWords(True)
            recognizer.SetPartialWords(True)
            
            self.recognizers[session_id] = recognizer
            
            # 调用父类方法初始化流状态
            return await super().start_stream_processing(session_id)
            
        except Exception as e:
            logger.error(f"启动Vosk流处理失败 {session_id}: {e}")
            return False
    
    async def process_audio_chunk(self, session_id: str, audio_chunk_base64: str) -> Optional[Dict[str, Any]]:
        """处理真实的音频数据"""
        if session_id not in self.recognizers or session_id not in self.active_streams:
            return None
        
        try:
            # 解码音频数据
            audio_data = base64.b64decode(audio_chunk_base64)
            
            # Vosk处理
            recognizer = self.recognizers[session_id]
            
            if recognizer.AcceptWaveform(audio_data):
                # 完整结果
                result = json.loads(recognizer.Result())
                if result.get("text"):
                    return {
                        "partial": False,
                        "text": result["text"],
                        "confidence": result.get("confidence", 1.0),
                        "words": result.get("words", []),
                        "timestamp": datetime.utcnow().isoformat()
                    }
            else:
                # 部分结果
                partial_result = json.loads(recognizer.PartialResult())
                if partial_result.get("partial"):
                    return {
                        "partial": True,
                        "text": partial_result["partial"],
                        "confidence": 0.8,
                        "timestamp": datetime.utcnow().isoformat()
                    }
            
            # 更新流状态
            stream_info = self.active_streams[session_id]
            stream_info["audio_chunks"].append(audio_data)
            stream_info["total_bytes"] += len(audio_data)
            
            return None
            
        except Exception as e:
            logger.error(f"Vosk处理音频块失败 {session_id}: {e}")
            return None
    
    async def get_final_transcription(self, session_id: str) -> Optional[str]:
        """获取Vosk最终转录结果"""
        if session_id not in self.recognizers:
            return None
        
        try:
            recognizer = self.recognizers[session_id]
            
            # 获取最终结果
            final_result = json.loads(recognizer.FinalResult())
            final_text = final_result.get("text", "")
            
            # 清理资源
            del self.recognizers[session_id]
            if session_id in self.active_streams:
                del self.active_streams[session_id]
            
            logger.info(f"Vosk最终转录 {session_id}: {final_text}")
            
            return final_text
            
        except Exception as e:
            logger.error(f"获取Vosk最终转录失败 {session_id}: {e}")
            return None
    
    async def health_check(self) -> Dict[str, Any]:
        """Vosk健康检查"""
        base_status = await super().health_check()
        base_status.update({
            "mode": "vosk",
            "active_recognizers": len(self.recognizers)
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