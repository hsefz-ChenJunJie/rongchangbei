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
# 真实的Vosk集成代码（待启用）
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
    # 从配置文件读取使用真实Vosk的设置
    use_real_vosk = settings.use_real_vosk
    
    logger.info(f"STT服务配置: use_real_vosk={use_real_vosk}")
    
    if use_real_vosk:
        logger.info("使用真实Vosk STT服务")
        return VoskSTTService()
    else:
        logger.info("使用Mock STT服务")
        return STTService()  # Mock版本