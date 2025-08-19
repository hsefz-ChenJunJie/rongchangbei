"""
会话和消息数据模型定义
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class SessionStatus(str, Enum):
    """会话状态枚举"""
    IDLE = "idle"  # 空闲状态，等待新消息或手动触发
    RECORDING_MESSAGE = "recording_message"  # 正在录制消息中
    PROCESSING_STT = "processing_stt"  # 处理语音转文字中
    GENERATING_OPINIONS = "generating_opinions"  # 自动生成意见建议中
    GENERATING_RESPONSE = "generating_response"  # 手动触发的回答生成中


class HistoryMessage(BaseModel):
    """历史消息数据模型（对话开始时传入）"""
    message_id: str = Field(description="历史消息ID")
    sender: str = Field(description="消息发送者标识")
    content: str = Field(description="消息内容")


class Message(BaseModel):
    """消息数据模型"""
    id: str = Field(description="消息唯一ID")
    sender: str = Field(description="消息发送者标识")
    content: str = Field(description="消息内容")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="消息时间戳")
    is_user_selected: bool = Field(default=False, description="是否为用户选择的LLM回答")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class Session(BaseModel):
    """会话数据模型"""
    id: str = Field(description="会话唯一ID")
    scenario_description: Optional[str] = Field(default=None, description="对话情景描述")
    response_count: int = Field(default=3, ge=1, le=5, description="生成回答数量")
    status: SessionStatus = Field(default=SessionStatus.IDLE, description="会话状态")
    
    # 消息相关
    history_messages: List[HistoryMessage] = Field(default_factory=list, description="历史消息（对话开始时传入）")
    messages: List[Message] = Field(default_factory=list, description="消息历史")
    current_message_id: Optional[str] = Field(default=None, description="当前处理中的消息ID")
    current_message_sender: Optional[str] = Field(default=None, description="当前消息发送者")
    
    # 用户反馈
    modifications: List[str] = Field(default_factory=list, description="修改建议列表")
    focused_message_ids: List[str] = Field(default_factory=list, description="聚焦消息ID列表")
    user_opinion: Optional[str] = Field(default=None, description="用户意见倾向")
    
    # 请求管理
    active_opinion_request_id: Optional[str] = Field(default=None, description="进行中的意见生成请求ID")
    active_response_request_id: Optional[str] = Field(default=None, description="进行中的回答生成请求ID")
    
    # 时间戳
    created_at: datetime = Field(default_factory=datetime.utcnow, description="会话创建时间")
    updated_at: datetime = Field(default_factory=datetime.utcnow, description="会话更新时间")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

    def add_message(self, message_id: str, sender: str, content: str, is_user_selected: bool = False) -> Message:
        """添加新消息"""
        message = Message(
            id=message_id,
            sender=sender,
            content=content,
            is_user_selected=is_user_selected
        )
        self.messages.append(message)
        self.updated_at = datetime.utcnow()
        return message

    def get_message(self, message_id: str) -> Optional[Message]:
        """根据ID获取消息"""
        for message in self.messages:
            if message.id == message_id:
                return message
        return None

    def get_focused_messages(self) -> List[Message]:
        """获取聚焦的消息列表"""
        if not self.focused_message_ids:
            return []
        
        focused_messages = []
        for message_id in self.focused_message_ids:
            message = self.get_message(message_id)
            if message:
                focused_messages.append(message)
        return focused_messages

    def add_modification(self, modification: str):
        """添加修改建议"""
        self.modifications.append(modification)
        self.updated_at = datetime.utcnow()

    def clear_modifications(self):
        """清空修改建议"""
        self.modifications.clear()
        self.updated_at = datetime.utcnow()

    def update_scenario(self, supplement: str):
        """更新情景描述（完全替换）"""
        self.scenario_description = supplement
        self.updated_at = datetime.utcnow()

    def update_response_count(self, count: int):
        """更新回答生成数量"""
        if 1 <= count <= 5:
            self.response_count = count
            self.updated_at = datetime.utcnow()

    def set_focused_messages(self, message_ids: List[str]):
        """设置聚焦消息"""
        self.focused_message_ids = message_ids.copy()
        self.updated_at = datetime.utcnow()

    def set_user_opinion(self, opinion: str):
        """设置用户意见倾向"""
        self.user_opinion = opinion
        self.updated_at = datetime.utcnow()
    
    def set_history_messages(self, history_messages: List[Dict[str, str]]):
        """设置历史消息"""
        self.history_messages = [
            HistoryMessage(
                message_id=msg["message_id"],
                sender=msg["sender"],
                content=msg["content"]
            ) for msg in history_messages
        ]
        self.updated_at = datetime.utcnow()

    def update_status(self, status: SessionStatus):
        """更新会话状态"""
        self.status = status
        self.updated_at = datetime.utcnow()

    def start_message(self, sender: str) -> str:
        """开始新消息，返回临时消息ID"""
        # 生成临时消息ID
        temp_id = f"temp_{len(self.messages)}_{int(datetime.utcnow().timestamp() * 1000)}"
        self.current_message_id = temp_id
        self.current_message_sender = sender
        self.update_status(SessionStatus.RECORDING_MESSAGE)
        return temp_id

    def end_message(self, content: str) -> str:
        """结束消息，返回正式消息ID"""
        if not self.current_message_sender:
            raise ValueError("没有进行中的消息")
        
        # 生成正式消息ID
        formal_id = f"msg_{len(self.messages) + 1:03d}"
        
        # 添加消息到历史记录
        self.add_message(formal_id, self.current_message_sender, content)
        
        # 清理临时状态
        self.current_message_id = None
        self.current_message_sender = None
        self.update_status(SessionStatus.IDLE)
        
        return formal_id

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            "id": self.id,
            "scenario_description": self.scenario_description,
            "response_count": self.response_count,
            "status": self.status.value,
            "messages": [msg.dict() for msg in self.messages],
            "current_message_id": self.current_message_id,
            "current_message_sender": self.current_message_sender,
            "modifications": self.modifications,
            "focused_message_ids": self.focused_message_ids,
            "user_opinion": self.user_opinion,
            "active_opinion_request_id": self.active_opinion_request_id,
            "active_response_request_id": self.active_response_request_id,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat()
        }


class RequestInfo(BaseModel):
    """请求信息模型"""
    id: str = Field(description="请求唯一ID")
    session_id: str = Field(description="关联的会话ID")
    request_type: str = Field(description="请求类型（opinion/response）")
    status: str = Field(description="请求状态（pending/completed/cancelled）")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="请求创建时间")
    completed_at: Optional[datetime] = Field(default=None, description="请求完成时间")
    error_message: Optional[str] = Field(default=None, description="错误信息")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }