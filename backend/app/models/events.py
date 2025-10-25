"""
WebSocket事件数据模型定义
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Literal, Union
from datetime import datetime


# ===============================
# 前端 → 后端事件数据模型
# ===============================

class HistoryMessage(BaseModel):
    """历史消息数据"""
    message_id: str = Field(description="前端提供的历史消息ID")
    sender: str = Field(description="消息发送者标识")
    content: str = Field(description="消息内容")


class ConversationStartData(BaseModel):
    """对话开始事件数据"""
    scenario_description: Optional[str] = Field(default=None, description="对话情景描述文本")
    response_count: int = Field(ge=1, le=5, description="1-5之间的整数，生成回答数量")
    history_messages: Optional[List[HistoryMessage]] = Field(default=None, description="之前会话中记录的所有消息")


class MessageStartData(BaseModel):
    """消息开始事件数据"""
    session_id: str = Field(description="会话唯一ID")
    sender: str = Field(description="消息发送者标识")


class AudioStreamData(BaseModel):
    """音频流事件数据"""
    session_id: str = Field(description="会话唯一ID")
    audio_chunk: str = Field(description="base64编码的音频数据")


class MessageEndData(BaseModel):
    """消息结束事件数据"""
    session_id: str = Field(description="目标会话标识")


class ManualGenerateData(BaseModel):
    """手动触发生成回答事件数据"""
    session_id: str = Field(description="目标会话标识")
    focused_message_ids: Optional[List[str]] = Field(default=None, description="用户选择聚焦的消息ID数组")
    user_corpus: Optional[str] = Field(default=None, description="用户提供的语料库")


class UserModificationData(BaseModel):
    """用户修改建议事件数据"""
    session_id: str = Field(description="目标会话标识")
    modification: str = Field(description="对LLM回复的修改建议")


class UserSelectedResponseData(BaseModel):
    """用户选择回答事件数据"""
    session_id: str = Field(description="目标会话标识")
    selected_content: str = Field(description="用户选择的回答内容")
    sender: str = Field(description="消息发送者（即用户自己）")


class ScenarioSupplementData(BaseModel):
    """情景补充事件数据"""
    session_id: str = Field(description="目标会话标识")
    supplement: str = Field(description="补充情景描述")


class ResponseCountUpdateData(BaseModel):
    """回答数量修改事件数据"""
    session_id: str = Field(description="目标会话标识")
    response_count: int = Field(ge=1, le=5, description="新的建议回答数量，1-5之间的整数")


class ConversationEndData(BaseModel):
    """对话结束事件数据"""
    session_id: str = Field(description="目标会话标识")


class SessionResumeData(BaseModel):
    """会话恢复请求事件数据"""
    session_id: str = Field(description="要恢复的会话ID")


# ===============================
# 测试专用事件数据模型
# ===============================

class GetMessageHistoryData(BaseModel):
    """获取消息历史测试事件数据"""
    session_id: str = Field(description="目标会话标识")


class MessageHistoryItem(BaseModel):
    """消息历史项数据"""
    message_id: str = Field(description="消息唯一ID")
    sender: str = Field(description="消息发送者")
    content: str = Field(description="消息内容")
    created_at: str = Field(description="消息创建时间")
    message_type: Literal["history", "recording", "selected_response"] = Field(description="消息类型")


class MessageHistoryResponseData(BaseModel):
    """消息历史响应事件数据"""
    session_id: str = Field(description="目标会话标识")
    messages: List[MessageHistoryItem] = Field(description="消息历史列表")
    total_count: int = Field(description="总消息数量")
    request_id: Optional[str] = Field(default=None, description="用于请求追踪")


# ===============================
# 后端 → 前端事件数据模型
# ===============================

class SessionCreatedData(BaseModel):
    """会话创建确认事件数据"""
    session_id: str = Field(description="生成的唯一会话ID")


class MessageRecordedData(BaseModel):
    """消息记录确认事件数据"""
    session_id: str = Field(description="目标会话标识")
    message_id: str = Field(description="分配给消息的ID")
    message_content: Optional[str] = Field(default=None, description="消息内容（仅录制消息时包含）")


class SessionRestoredData(BaseModel):
    """会话恢复成功事件数据"""
    session_id: str = Field(description="恢复的会话ID")
    status: str = Field(description="会话状态")
    message_count: int = Field(description="消息数量")
    scenario_description: Optional[str] = Field(default=None, description="对话情景描述")
    response_count: int = Field(description="回答生成数量")
    has_modifications: bool = Field(description="是否有修改建议")
    restored_at: str = Field(description="恢复时间")


class LLMResponseData(BaseModel):
    """LLM回答响应事件数据"""
    session_id: str = Field(description="目标会话标识")
    suggestions: List[str] = Field(description="回答建议数组")
    request_id: Optional[str] = Field(default=None, description="用于请求追踪")




class StatusUpdateData(BaseModel):
    """状态更新事件数据"""
    session_id: str = Field(description="目标会话标识")
    status: Literal["idle", "recording_message", "processing_stt", "generating_response"] = Field(
        description="会话状态"
    )
    message: Optional[str] = Field(default=None, description="状态描述")


class ErrorData(BaseModel):
    """错误事件数据"""
    session_id: Optional[str] = Field(default=None, description="会话相关错误才包含")
    error_code: str = Field(description="标准化错误代码")
    message: str = Field(description="用户友好的错误描述")
    details: Optional[str] = Field(default=None, description="调试用的详细信息")


# ===============================
# 完整的事件模型
# ===============================

class WebSocketEvent(BaseModel):
    """通用WebSocket事件模型"""
    type: str = Field(description="事件类型")
    data: dict = Field(description="事件数据")
    timestamp: Optional[datetime] = Field(default_factory=datetime.utcnow, description="事件时间戳")


# 前端发送事件类型定义
class ConversationStartEvent(BaseModel):
    type: Literal["conversation_start"] = "conversation_start"
    data: ConversationStartData


class MessageStartEvent(BaseModel):
    type: Literal["message_start"] = "message_start"
    data: MessageStartData


class AudioStreamEvent(BaseModel):
    type: Literal["audio_stream"] = "audio_stream"
    data: AudioStreamData


class MessageEndEvent(BaseModel):
    type: Literal["message_end"] = "message_end"
    data: MessageEndData


class ManualGenerateEvent(BaseModel):
    type: Literal["manual_generate"] = "manual_generate"
    data: ManualGenerateData


class UserModificationEvent(BaseModel):
    type: Literal["user_modification"] = "user_modification"
    data: UserModificationData


class UserSelectedResponseEvent(BaseModel):
    type: Literal["user_selected_response"] = "user_selected_response"
    data: UserSelectedResponseData


class ScenarioSupplementEvent(BaseModel):
    type: Literal["scenario_supplement"] = "scenario_supplement"
    data: ScenarioSupplementData


class ResponseCountUpdateEvent(BaseModel):
    type: Literal["response_count_update"] = "response_count_update"
    data: ResponseCountUpdateData


class ConversationEndEvent(BaseModel):
    type: Literal["conversation_end"] = "conversation_end"
    data: ConversationEndData


class SessionResumeEvent(BaseModel):
    type: Literal["session_resume"] = "session_resume"
    data: SessionResumeData


# 测试专用事件类型定义
class GetMessageHistoryEvent(BaseModel):
    type: Literal["get_message_history"] = "get_message_history"
    data: GetMessageHistoryData


# 后端发送事件类型定义
class SessionCreatedEvent(BaseModel):
    type: Literal["session_created"] = "session_created"
    data: SessionCreatedData


class MessageRecordedEvent(BaseModel):
    type: Literal["message_recorded"] = "message_recorded"
    data: MessageRecordedData


class LLMResponseEvent(BaseModel):
    type: Literal["llm_response"] = "llm_response"
    data: LLMResponseData


class StatusUpdateEvent(BaseModel):
    type: Literal["status_update"] = "status_update"
    data: StatusUpdateData


class ErrorEvent(BaseModel):
    type: Literal["error"] = "error"
    data: ErrorData


class SessionRestoredEvent(BaseModel):
    type: Literal["session_restored"] = "session_restored"
    data: SessionRestoredData


class MessageHistoryResponseEvent(BaseModel):
    type: Literal["message_history_response"] = "message_history_response"
    data: MessageHistoryResponseData


# 联合类型定义
IncomingEvent = Union[
    ConversationStartEvent,
    MessageStartEvent,
    AudioStreamEvent,
    MessageEndEvent,
    ManualGenerateEvent,
    UserModificationEvent,
    UserSelectedResponseEvent,
    ScenarioSupplementEvent,
    ResponseCountUpdateEvent,
    ConversationEndEvent,
    SessionResumeEvent,
    GetMessageHistoryEvent
]

OutgoingEvent = Union[
    SessionCreatedEvent,
    MessageRecordedEvent,
    LLMResponseEvent,
    StatusUpdateEvent,
    ErrorEvent,
    SessionRestoredEvent,
    MessageHistoryResponseEvent
]


# ===============================
# 事件类型常量
# ===============================

class EventTypes:
    """事件类型常量"""
    
    # 前端 → 后端事件
    CONVERSATION_START = "conversation_start"
    MESSAGE_START = "message_start"
    AUDIO_STREAM = "audio_stream"
    MESSAGE_END = "message_end"
    MANUAL_GENERATE = "manual_generate"
    USER_MODIFICATION = "user_modification"
    USER_SELECTED_RESPONSE = "user_selected_response"
    SCENARIO_SUPPLEMENT = "scenario_supplement"
    RESPONSE_COUNT_UPDATE = "response_count_update"
    CONVERSATION_END = "conversation_end"
    SESSION_RESUME = "session_resume"
    
    # 测试专用事件
    GET_MESSAGE_HISTORY = "get_message_history"
    
    # 后端 → 前端事件
    SESSION_CREATED = "session_created"
    MESSAGE_RECORDED = "message_recorded"
    LLM_RESPONSE = "llm_response"
    STATUS_UPDATE = "status_update"
    ERROR = "error"
    SESSION_RESTORED = "session_restored"
    MESSAGE_HISTORY_RESPONSE = "message_history_response"

# --- Data Models for Events ---


# ===============================
# 错误代码常量
# ===============================

class ErrorCodes:
    """错误代码常量"""
    
    # 验证错误
    INVALID_EVENT_TYPE = "INVALID_EVENT_TYPE"
    INVALID_EVENT_DATA = "INVALID_EVENT_DATA"
    MISSING_REQUIRED_FIELD = "MISSING_REQUIRED_FIELD"
    
    # 会话错误
    SESSION_NOT_FOUND = "SESSION_NOT_FOUND"
    SESSION_ALREADY_EXISTS = "SESSION_ALREADY_EXISTS"
    SESSION_EXPIRED = "SESSION_EXPIRED"
    
    # 服务错误
    STT_SERVICE_ERROR = "STT_SERVICE_ERROR"
    LLM_SERVICE_ERROR = "LLM_SERVICE_ERROR"
    SERVICE_TIMEOUT = "SERVICE_TIMEOUT"
    
    # 系统错误
    INTERNAL_ERROR = "INTERNAL_ERROR"
    WEBSOCKET_ERROR = "WEBSOCKET_ERROR"