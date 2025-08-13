"""
会话管理器服务
"""
import uuid
import logging
from typing import Dict, Optional, List
from datetime import datetime

from app.models.session import Session, Message, SessionStatus

logger = logging.getLogger(__name__)


class SessionManager:
    """会话管理器"""
    
    def __init__(self):
        self.sessions: Dict[str, Session] = {}
    
    # ===============================
    # 会话生命周期管理
    # ===============================
    
    def create_session(self, session_id: str = None, scenario_description: str = None, response_count: int = 3) -> Session:
        """
        创建新会话
        
        Args:
            session_id: 会话ID，如果不提供则自动生成
            scenario_description: 对话情景描述
            response_count: 生成回答数量
            
        Returns:
            Session: 创建的会话对象
        """
        if session_id is None:
            session_id = str(uuid.uuid4())
        
        if session_id in self.sessions:
            raise ValueError(f"会话ID已存在: {session_id}")
        
        session = Session(
            id=session_id,
            scenario_description=scenario_description,
            response_count=response_count
        )
        
        self.sessions[session_id] = session
        
        logger.info(f"会话创建: {session_id}, 情景: {scenario_description}, 回答数量: {response_count}")
        
        return session
    
    def get_session(self, session_id: str) -> Optional[Session]:
        """
        获取会话
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[Session]: 会话对象，如果不存在则返回None
        """
        return self.sessions.get(session_id)
    
    def session_exists(self, session_id: str) -> bool:
        """
        检查会话是否存在
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 会话是否存在
        """
        return session_id in self.sessions
    
    def destroy_session(self, session_id: str) -> bool:
        """
        销毁会话
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 是否成功销毁
        """
        if session_id in self.sessions:
            del self.sessions[session_id]
            logger.info(f"会话销毁: {session_id}")
            return True
        return False
    
    def get_all_sessions(self) -> List[Session]:
        """
        获取所有会话
        
        Returns:
            List[Session]: 所有会话列表
        """
        return list(self.sessions.values())
    
    def get_session_count(self) -> int:
        """
        获取会话总数
        
        Returns:
            int: 会话总数
        """
        return len(self.sessions)
    
    # ===============================
    # 消息管理
    # ===============================
    
    def start_message(self, session_id: str, sender: str) -> str:
        """
        开始新消息
        
        Args:
            session_id: 会话ID
            sender: 消息发送者
            
        Returns:
            str: 临时消息ID
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        temp_id = session.start_message(sender)
        
        logger.info(f"消息开始: {session_id}, 发送者: {sender}, 临时ID: {temp_id}")
        
        return temp_id
    
    def end_message(self, session_id: str, content: str) -> str:
        """
        结束消息
        
        Args:
            session_id: 会话ID
            content: 消息内容
            
        Returns:
            str: 正式消息ID
            
        Raises:
            ValueError: 会话不存在或没有进行中的消息
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        formal_id = session.end_message(content)
        
        logger.info(f"消息结束: {session_id}, 正式ID: {formal_id}, 内容长度: {len(content)}")
        
        return formal_id
    
    def add_user_selected_message(self, session_id: str, content: str, sender: str) -> str:
        """
        添加用户选择的回答作为新消息
        
        Args:
            session_id: 会话ID
            content: 消息内容
            sender: 消息发送者
            
        Returns:
            str: 消息ID
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        # 生成消息ID
        message_id = f"usr_{len(session.messages) + 1:03d}"
        
        # 添加消息
        message = session.add_message(message_id, sender, content, is_user_selected=True)
        
        logger.info(f"用户选择回答添加: {session_id}, 消息ID: {message_id}")
        
        return message_id
    
    def get_messages(self, session_id: str) -> List[Message]:
        """
        获取会话的所有消息
        
        Args:
            session_id: 会话ID
            
        Returns:
            List[Message]: 消息列表
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        return session.messages
    
    def get_message(self, session_id: str, message_id: str) -> Optional[Message]:
        """
        获取指定消息
        
        Args:
            session_id: 会话ID
            message_id: 消息ID
            
        Returns:
            Optional[Message]: 消息对象，如果不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return session.get_message(message_id)
    
    def get_focused_messages(self, session_id: str, message_ids: List[str] = None) -> List[Message]:
        """
        获取聚焦的消息
        
        Args:
            session_id: 会话ID
            message_ids: 指定的消息ID列表，如果不提供则使用会话中保存的聚焦消息
            
        Returns:
            List[Message]: 聚焦的消息列表
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        if message_ids is not None:
            # 使用指定的消息ID列表
            focused_messages = []
            for message_id in message_ids:
                message = session.get_message(message_id)
                if message:
                    focused_messages.append(message)
            return focused_messages
        else:
            # 使用会话中保存的聚焦消息
            return session.get_focused_messages()
    
    # ===============================
    # 状态管理
    # ===============================
    
    def get_session_status(self, session_id: str) -> Optional[SessionStatus]:
        """
        获取会话状态
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[SessionStatus]: 会话状态，如果会话不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return session.status
    
    def set_session_status(self, session_id: str, status: SessionStatus):
        """
        设置会话状态
        
        Args:
            session_id: 会话ID
            status: 新状态
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        old_status = session.status
        session.update_status(status)
        
        logger.info(f"会话状态更新: {session_id}, {old_status} -> {status}")
    
    # ===============================
    # 用户反馈管理
    # ===============================
    
    def add_modification(self, session_id: str, modification: str):
        """
        添加修改建议
        
        Args:
            session_id: 会话ID
            modification: 修改建议
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        session.add_modification(modification)
        
        logger.info(f"修改建议添加: {session_id}, 修改: {modification}")
    
    def clear_modifications(self, session_id: str):
        """
        清空修改建议
        
        Args:
            session_id: 会话ID
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        count = len(session.modifications)
        session.clear_modifications()
        
        logger.info(f"修改建议清空: {session_id}, 清空了 {count} 条建议")
    
    def get_modifications(self, session_id: str) -> List[str]:
        """
        获取修改建议列表
        
        Args:
            session_id: 会话ID
            
        Returns:
            List[str]: 修改建议列表
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        return session.modifications
    
    def set_focused_messages(self, session_id: str, message_ids: List[str]):
        """
        设置聚焦消息
        
        Args:
            session_id: 会话ID
            message_ids: 聚焦的消息ID列表
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        session.set_focused_messages(message_ids)
        
        logger.info(f"聚焦消息设置: {session_id}, 消息IDs: {message_ids}")
    
    def set_user_opinion(self, session_id: str, opinion: str):
        """
        设置用户意见倾向
        
        Args:
            session_id: 会话ID
            opinion: 用户意见倾向
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        session.set_user_opinion(opinion)
        
        logger.info(f"用户意见设置: {session_id}, 意见: {opinion}")
    
    def get_user_opinion(self, session_id: str) -> Optional[str]:
        """
        获取用户意见倾向
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[str]: 用户意见倾向，如果不存在则返回None
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        return session.user_opinion
    
    # ===============================
    # 配置管理
    # ===============================
    
    def update_scenario(self, session_id: str, supplement: str):
        """
        更新对话情景描述
        
        Args:
            session_id: 会话ID
            supplement: 情景补充内容
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        old_scenario = session.scenario_description
        session.update_scenario(supplement)
        
        logger.info(f"情景更新: {session_id}, 旧情景: {old_scenario}, 新情景: {supplement}")
    
    def update_response_count(self, session_id: str, count: int):
        """
        更新回答生成数量
        
        Args:
            session_id: 会话ID
            count: 新的回答数量
            
        Raises:
            ValueError: 会话不存在或数量无效
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        if not (1 <= count <= 5):
            raise ValueError(f"回答数量必须在1-5之间: {count}")
        
        old_count = session.response_count
        session.update_response_count(count)
        
        logger.info(f"回答数量更新: {session_id}, {old_count} -> {count}")
    
    def get_response_count(self, session_id: str) -> Optional[int]:
        """
        获取回答生成数量
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[int]: 回答数量，如果会话不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return session.response_count
    
    def get_scenario_description(self, session_id: str) -> Optional[str]:
        """
        获取对话情景描述
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[str]: 情景描述，如果不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return session.scenario_description
    
    # ===============================
    # 请求管理
    # ===============================
    
    def set_active_opinion_request(self, session_id: str, request_id: str):
        """
        设置进行中的意见生成请求
        
        Args:
            session_id: 会话ID
            request_id: 请求ID
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        session.active_opinion_request_id = request_id
        session.updated_at = datetime.utcnow()
        
        logger.debug(f"设置意见生成请求: {session_id}, 请求ID: {request_id}")
    
    def set_active_response_request(self, session_id: str, request_id: str):
        """
        设置进行中的回答生成请求
        
        Args:
            session_id: 会话ID
            request_id: 请求ID
            
        Raises:
            ValueError: 会话不存在
        """
        session = self.get_session(session_id)
        if not session:
            raise ValueError(f"会话不存在: {session_id}")
        
        session.active_response_request_id = request_id
        session.updated_at = datetime.utcnow()
        
        logger.debug(f"设置回答生成请求: {session_id}, 请求ID: {request_id}")
    
    def clear_active_opinion_request(self, session_id: str):
        """
        清除进行中的意见生成请求
        
        Args:
            session_id: 会话ID
        """
        session = self.get_session(session_id)
        if session:
            session.active_opinion_request_id = None
            session.updated_at = datetime.utcnow()
            logger.debug(f"清除意见生成请求: {session_id}")
    
    def clear_active_response_request(self, session_id: str):
        """
        清除进行中的回答生成请求
        
        Args:
            session_id: 会话ID
        """
        session = self.get_session(session_id)
        if session:
            session.active_response_request_id = None
            session.updated_at = datetime.utcnow()
            logger.debug(f"清除回答生成请求: {session_id}")
    
    def get_active_opinion_request(self, session_id: str) -> Optional[str]:
        """
        获取进行中的意见生成请求ID
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[str]: 请求ID，如果不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return session.active_opinion_request_id
    
    def get_active_response_request(self, session_id: str) -> Optional[str]:
        """
        获取进行中的回答生成请求ID
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[str]: 请求ID，如果不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return session.active_response_request_id
    
    # ===============================
    # 统计和调试
    # ===============================
    
    def get_session_summary(self, session_id: str) -> Optional[dict]:
        """
        获取会话摘要信息
        
        Args:
            session_id: 会话ID
            
        Returns:
            Optional[dict]: 会话摘要，如果会话不存在则返回None
        """
        session = self.get_session(session_id)
        if not session:
            return None
        
        return {
            "session_id": session.id,
            "status": session.status.value,
            "message_count": len(session.messages),
            "modification_count": len(session.modifications),
            "focused_message_count": len(session.focused_message_ids),
            "has_scenario": session.scenario_description is not None,
            "has_user_opinion": session.user_opinion is not None,
            "response_count": session.response_count,
            "created_at": session.created_at.isoformat(),
            "updated_at": session.updated_at.isoformat(),
            "active_opinion_request": session.active_opinion_request_id,
            "active_response_request": session.active_response_request_id
        }
    
    def get_all_session_summaries(self) -> List[dict]:
        """
        获取所有会话的摘要信息
        
        Returns:
            List[dict]: 所有会话摘要列表
        """
        summaries = []
        for session_id in self.sessions:
            summary = self.get_session_summary(session_id)
            if summary:
                summaries.append(summary)
        
        return summaries
    
    def cleanup_expired_sessions(self, max_age_hours: int = 24) -> int:
        """
        清理过期会话
        
        Args:
            max_age_hours: 最大会话年龄（小时）
            
        Returns:
            int: 清理的会话数量
        """
        from datetime import datetime, timedelta
        
        cutoff_time = datetime.utcnow() - timedelta(hours=max_age_hours)
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            if session.updated_at < cutoff_time:
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            self.destroy_session(session_id)
        
        if expired_sessions:
            logger.info(f"清理过期会话: {len(expired_sessions)} 个，IDs: {expired_sessions}")
        
        return len(expired_sessions)