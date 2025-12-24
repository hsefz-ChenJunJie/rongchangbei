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
    user_corpus: Optional[str] = Field(default=None, description="用户提供的语料库")
    user_background: Optional[str] = Field(default=None, description="用户背景信息（身份/角色等）")
    user_preferences: Optional[str] = Field(default=None, description="用户的偏好与喜好")
    user_recent_experiences: Optional[str] = Field(default=None, description="用户最近的经历或事件")
    
    # 请求管理
    active_opinion_request_id: Optional[str] = Field(default=None, description="进行中的意见生成请求ID")
    active_response_request_id: Optional[str] = Field(default=None, description="进行中的回答生成请求ID")
    
    # 断连保护（累积模式）
    partial_transcription: Optional[str] = Field(default=None, description="断连时的部分转录内容")
    audio_chunks_count: int = Field(default=0, description="断连时已收集的音频块数量") 
    accumulated_audio_data: Optional[bytes] = Field(default=None, description="断连时累积的音频数据")
    is_recovering_from_disconnect: bool = Field(default=False, description="是否正在从断连中恢复")
    
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

    def get_focused_messages(self, message_ids: Optional[List[str]] = None) -> List[Message]:
        """获取聚焦的消息列表；可传入自定义ID列表，默认使用会话内记录的聚焦ID"""
        ids = message_ids if message_ids is not None else self.focused_message_ids
        if not ids:
            return []
        
        focused_messages: List[Message] = []
        for message_id in ids:
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

    def update_user_context(
        self,
        user_corpus: Optional[str] = None,
        user_background: Optional[str] = None,
        user_preferences: Optional[str] = None,
        user_recent_experiences: Optional[str] = None,
    ):
        """更新用户相关上下文信息"""
        if user_corpus is not None:
            self.user_corpus = user_corpus
        if user_background is not None:
            self.user_background = user_background
        if user_preferences is not None:
            self.user_preferences = user_preferences
        if user_recent_experiences is not None:
            self.user_recent_experiences = user_recent_experiences
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
        
        # 清理临时状态和断连保护状态
        self.current_message_id = None
        self.current_message_sender = None
        self.partial_transcription = None
        self.audio_chunks_count = 0
        self.accumulated_audio_data = None
        self.is_recovering_from_disconnect = False
        self.update_status(SessionStatus.IDLE)
        
        return formal_id

    def set_partial_transcription(self, partial_text: str, chunks_count: int):
        """设置断连时的部分转录内容"""
        self.partial_transcription = partial_text
        self.audio_chunks_count = chunks_count
        self.updated_at = datetime.utcnow()

    def set_accumulated_audio(self, audio_data: bytes):
        """设置断连时的累积音频数据"""
        self.accumulated_audio_data = audio_data
        self.audio_chunks_count = len(audio_data) if audio_data else 0
        self.updated_at = datetime.utcnow()

    def get_accumulated_audio(self) -> Optional[bytes]:
        """获取断连时保存的累积音频数据"""
        return self.accumulated_audio_data
        
    def mark_recovering_from_disconnect(self):
        """标记正在从断连中恢复"""
        self.is_recovering_from_disconnect = True
        self.updated_at = datetime.utcnow()
        
    def is_recording_message(self) -> bool:
        """检查是否正在录制消息"""
        return self.status == SessionStatus.RECORDING_MESSAGE
        
    def has_partial_content(self) -> bool:
        """检查是否有部分转录内容"""
        return self.partial_transcription is not None or self.audio_chunks_count > 0

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
            "user_corpus": self.user_corpus,
            "user_background": self.user_background,
            "user_preferences": self.user_preferences,
            "user_recent_experiences": self.user_recent_experiences,
            "active_opinion_request_id": self.active_opinion_request_id,
            "active_response_request_id": self.active_response_request_id,
            "partial_transcription": self.partial_transcription,
            "audio_chunks_count": self.audio_chunks_count,
            "is_recovering_from_disconnect": self.is_recovering_from_disconnect,
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
