"""
会话持久化管理器
实现会话的文件存储、恢复和过期清理功能
"""
import os
import json
import logging
import asyncio
from typing import Dict, Optional, List
from datetime import datetime, timedelta
from pathlib import Path

from app.models.session import Session

logger = logging.getLogger(__name__)


class SessionPersistenceManager:
    """会话持久化管理器"""
    
    def __init__(self, persistence_dir: str = "./sessions", max_persistence_hours: int = 24):
        """
        初始化持久化管理器
        
        Args:
            persistence_dir: 会话存储目录
            max_persistence_hours: 最大持久化时间（小时）
        """
        self.persistence_dir = Path(persistence_dir)
        self.max_persistence_hours = max_persistence_hours
        
        # 确保存储目录存在
        self.persistence_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"会话持久化管理器初始化: 目录={self.persistence_dir}, 最大持久化时间={max_persistence_hours}小时")
    
    def _get_session_file_path(self, session_id: str) -> Path:
        """获取会话文件路径"""
        return self.persistence_dir / f"{session_id}.json"
    
    def _serialize_session(self, session: Session) -> dict:
        """序列化会话对象"""
        return {
            "id": session.id,
            "scenario_description": session.scenario_description,
            "response_count": session.response_count,
            "status": session.status.value,
            "messages": [
                {
                    "id": msg.id,
                    "sender": msg.sender,
                    "content": msg.content,
                    "timestamp": msg.timestamp.isoformat(),
                    "is_user_selected": msg.is_user_selected
                }
                for msg in session.messages
            ],
            "modifications": session.modifications,
            "focused_message_ids": session.focused_message_ids,
            "user_opinion": session.user_opinion,
            "current_message_sender": session.current_message_sender,
            "active_opinion_request_id": session.active_opinion_request_id,
            "active_response_request_id": session.active_response_request_id,
            "created_at": session.created_at.isoformat(),
            "updated_at": session.updated_at.isoformat(),
            "persisted_at": datetime.utcnow().isoformat()
        }
    
    def _deserialize_session(self, data: dict) -> Session:
        """反序列化会话对象"""
        from app.models.session import Message, SessionStatus
        
        # 创建会话对象
        session = Session(
            id=data["id"],
            scenario_description=data.get("scenario_description"),
            response_count=data.get("response_count", 3)
        )
        
        # 恢复基本属性
        session.status = SessionStatus(data.get("status", "idle"))
        session.modifications = data.get("modifications", [])
        session.focused_message_ids = data.get("focused_message_ids", [])
        session.user_opinion = data.get("user_opinion")
        session.current_message_sender = data.get("current_message_sender")
        session.active_opinion_request_id = data.get("active_opinion_request_id")
        session.active_response_request_id = data.get("active_response_request_id")
        
        # 恢复时间戳
        session.created_at = datetime.fromisoformat(data["created_at"])
        session.updated_at = datetime.fromisoformat(data["updated_at"])
        
        # 恢复消息列表
        session.messages = []
        for msg_data in data.get("messages", []):
            message = Message(
                id=msg_data["id"],
                sender=msg_data["sender"],
                content=msg_data["content"],
                is_user_selected=msg_data.get("is_user_selected", False)
            )
            message.timestamp = datetime.fromisoformat(msg_data["timestamp"])
            session.messages.append(message)
        
        return session
    
    async def save_session(self, session: Session) -> bool:
        """
        保存会话到文件
        
        Args:
            session: 要保存的会话对象
            
        Returns:
            bool: 是否保存成功
        """
        try:
            session_file = self._get_session_file_path(session.id)
            session_data = self._serialize_session(session)
            
            # 异步写入文件
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: session_file.write_text(
                    json.dumps(session_data, indent=2, ensure_ascii=False),
                    encoding='utf-8'
                )
            )
            
            logger.info(f"会话保存成功: {session.id}")
            return True
            
        except Exception as e:
            logger.error(f"保存会话失败 {session.id}: {e}")
            return False
    
    async def load_session(self, session_id: str) -> Optional[Session]:
        """
        从文件加载会话
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[Session]: 加载的会话对象，如果不存在或加载失败则返回None
        """
        try:
            session_file = self._get_session_file_path(session_id)
            
            if not session_file.exists():
                logger.debug(f"会话文件不存在: {session_id}")
                return None
            
            # 异步读取文件
            loop = asyncio.get_event_loop()
            content = await loop.run_in_executor(
                None,
                lambda: session_file.read_text(encoding='utf-8')
            )
            
            session_data = json.loads(content)
            session = self._deserialize_session(session_data)
            
            logger.info(f"会话加载成功: {session_id}")
            return session
            
        except Exception as e:
            logger.error(f"加载会话失败 {session_id}: {e}")
            return None
    
    async def delete_session(self, session_id: str) -> bool:
        """
        删除会话文件
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 是否删除成功
        """
        try:
            session_file = self._get_session_file_path(session_id)
            
            if session_file.exists():
                session_file.unlink()
                logger.info(f"会话文件删除成功: {session_id}")
                return True
            else:
                logger.debug(f"会话文件不存在，无需删除: {session_id}")
                return True
                
        except Exception as e:
            logger.error(f"删除会话文件失败 {session_id}: {e}")
            return False
    
    async def list_persisted_sessions(self) -> List[str]:
        """
        列出所有持久化的会话ID
        
        Returns:
            List[str]: 会话ID列表
        """
        try:
            session_files = list(self.persistence_dir.glob("*.json"))
            session_ids = [f.stem for f in session_files]
            
            logger.debug(f"发现 {len(session_ids)} 个持久化会话")
            return session_ids
            
        except Exception as e:
            logger.error(f"列出持久化会话失败: {e}")
            return []
    
    async def cleanup_expired_sessions(self) -> int:
        """
        清理过期的持久化会话
        
        Returns:
            int: 清理的会话数量
        """
        try:
            cutoff_time = datetime.utcnow() - timedelta(hours=self.max_persistence_hours)
            cleaned_count = 0
            
            session_files = list(self.persistence_dir.glob("*.json"))
            
            for session_file in session_files:
                try:
                    # 检查文件修改时间
                    file_mtime = datetime.fromtimestamp(session_file.stat().st_mtime)
                    
                    if file_mtime < cutoff_time:
                        session_file.unlink()
                        cleaned_count += 1
                        logger.debug(f"清理过期会话文件: {session_file.stem}")
                        
                except Exception as e:
                    logger.error(f"清理会话文件失败 {session_file}: {e}")
            
            if cleaned_count > 0:
                logger.info(f"清理过期会话完成: {cleaned_count} 个文件")
            
            return cleaned_count
            
        except Exception as e:
            logger.error(f"清理过期会话失败: {e}")
            return 0
    
    async def get_session_info(self, session_id: str) -> Optional[dict]:
        """
        获取会话基本信息（不完全加载会话）
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[dict]: 会话基本信息
        """
        try:
            session_file = self._get_session_file_path(session_id)
            
            if not session_file.exists():
                return None
            
            # 异步读取文件
            loop = asyncio.get_event_loop()
            content = await loop.run_in_executor(
                None,
                lambda: session_file.read_text(encoding='utf-8')
            )
            
            session_data = json.loads(content)
            
            return {
                "session_id": session_data["id"],
                "created_at": session_data["created_at"],
                "updated_at": session_data["updated_at"],
                "persisted_at": session_data.get("persisted_at"),
                "status": session_data.get("status", "idle"),
                "message_count": len(session_data.get("messages", [])),
                "has_scenario": session_data.get("scenario_description") is not None,
                "response_count": session_data.get("response_count", 3)
            }
            
        except Exception as e:
            logger.error(f"获取会话信息失败 {session_id}: {e}")
            return None
    
    async def get_storage_stats(self) -> dict:
        """
        获取存储统计信息
        
        Returns:
            dict: 存储统计信息
        """
        try:
            session_files = list(self.persistence_dir.glob("*.json"))
            total_sessions = len(session_files)
            total_size = sum(f.stat().st_size for f in session_files)
            
            # 计算过期会话数量
            cutoff_time = datetime.utcnow() - timedelta(hours=self.max_persistence_hours)
            expired_count = 0
            
            for session_file in session_files:
                file_mtime = datetime.fromtimestamp(session_file.stat().st_mtime)
                if file_mtime < cutoff_time:
                    expired_count += 1
            
            return {
                "storage_directory": str(self.persistence_dir),
                "total_sessions": total_sessions,
                "total_size_bytes": total_size,
                "total_size_mb": round(total_size / 1024 / 1024, 2),
                "expired_sessions": expired_count,
                "max_persistence_hours": self.max_persistence_hours,
                "stats_time": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"获取存储统计失败: {e}")
            return {
                "error": str(e),
                "stats_time": datetime.utcnow().isoformat()
            }


class PeriodicCleanupTask:
    """定期清理任务"""
    
    def __init__(self, persistence_manager: SessionPersistenceManager, interval_minutes: int = 60):
        """
        初始化定期清理任务
        
        Args:
            persistence_manager: 持久化管理器
            interval_minutes: 清理间隔（分钟）
        """
        self.persistence_manager = persistence_manager
        self.interval_minutes = interval_minutes
        self.cleanup_task = None
        self.is_running = False
        
    async def start(self):
        """启动定期清理任务"""
        if self.is_running:
            logger.warning("定期清理任务已在运行")
            return
        
        self.is_running = True
        self.cleanup_task = asyncio.create_task(self._cleanup_loop())
        logger.info(f"定期清理任务启动，间隔 {self.interval_minutes} 分钟")
    
    async def stop(self):
        """停止定期清理任务"""
        if not self.is_running:
            return
        
        self.is_running = False
        if self.cleanup_task:
            self.cleanup_task.cancel()
            try:
                await self.cleanup_task
            except asyncio.CancelledError:
                pass
        
        logger.info("定期清理任务已停止")
    
    async def _cleanup_loop(self):
        """清理循环"""
        try:
            while self.is_running:
                await asyncio.sleep(self.interval_minutes * 60)  # 转换为秒
                
                if self.is_running:  # 再次检查，避免在sleep期间被停止
                    cleaned_count = await self.persistence_manager.cleanup_expired_sessions()
                    if cleaned_count > 0:
                        logger.info(f"定期清理完成: {cleaned_count} 个过期会话")
                        
        except asyncio.CancelledError:
            logger.info("定期清理任务被取消")
        except Exception as e:
            logger.error(f"定期清理任务异常: {e}")
            self.is_running = False