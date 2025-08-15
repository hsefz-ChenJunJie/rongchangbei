"""
WebSocket事件处理器
"""
import json
import uuid
import logging
from typing import Dict, Any, Optional
from fastapi import WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from app.models.events import (
    EventTypes, ErrorCodes,
    IncomingEvent, OutgoingEvent,
    ConversationStartEvent, MessageStartEvent, AudioStreamEvent, MessageEndEvent,
    ManualGenerateEvent, UserModificationEvent, UserSelectedResponseEvent,
    ScenarioSupplementEvent, ResponseCountUpdateEvent, ConversationEndEvent,
    SessionCreatedEvent, MessageRecordedEvent, OpinionSuggestionsEvent,
    LLMResponseEvent, StatusUpdateEvent, ErrorEvent,
    SessionCreatedData, MessageRecordedData, OpinionSuggestionsData,
    LLMResponseData, StatusUpdateData, ErrorData
)

logger = logging.getLogger(__name__)


class WebSocketHandler:
    """WebSocket事件处理器"""
    
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.session_manager = None  # 将在初始化时注入
        self.stt_service = None      # 将在初始化时注入
        self.llm_service = None      # 将在初始化时注入
        self.request_manager = None  # 将在初始化时注入
    
    def set_services(self, session_manager, stt_service=None, llm_service=None, request_manager=None):
        """注入服务依赖"""
        self.session_manager = session_manager
        self.stt_service = stt_service
        self.llm_service = llm_service
        self.request_manager = request_manager
    
    # ===============================
    # 连接管理
    # ===============================
    
    async def connect(self, websocket: WebSocket, client_id: str):
        """接受WebSocket连接"""
        await websocket.accept()
        self.active_connections[client_id] = websocket
        logger.info(f"WebSocket连接建立: {client_id}")
    
    def disconnect(self, client_id: str):
        """断开WebSocket连接"""
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            logger.info(f"WebSocket连接断开: {client_id}")
    
    async def send_event(self, client_id: str, event: OutgoingEvent):
        """发送事件到客户端"""
        if client_id in self.active_connections:
            websocket = self.active_connections[client_id]
            try:
                event_dict = event.dict()
                await websocket.send_text(json.dumps(event_dict, ensure_ascii=False))
                logger.debug(f"发送事件到 {client_id}: {event.type}")
            except Exception as e:
                logger.error(f"发送事件失败 {client_id}: {e}")
                self.disconnect(client_id)
    
    # ===============================
    # 事件处理主循环
    # ===============================
    
    async def handle_connection(self, websocket: WebSocket, client_id: str):
        """处理WebSocket连接"""
        await self.connect(websocket, client_id)
        
        try:
            while True:
                # 接收消息
                data = await websocket.receive_text()
                try:
                    message = json.loads(data)
                    await self.handle_event(client_id, message)
                except json.JSONDecodeError as e:
                    await self.send_error(
                        client_id, 
                        ErrorCodes.INVALID_EVENT_DATA,
                        "无效的JSON格式",
                        str(e)
                    )
                except Exception as e:
                    logger.error(f"处理事件时发生错误: {e}")
                    await self.send_error(
                        client_id,
                        ErrorCodes.INTERNAL_ERROR,
                        "服务器内部错误",
                        str(e)
                    )
        
        except WebSocketDisconnect:
            self.disconnect(client_id)
        except Exception as e:
            logger.error(f"WebSocket连接错误: {e}")
            self.disconnect(client_id)
    
    async def handle_event(self, client_id: str, message: Dict[str, Any]):
        """处理接收到的事件"""
        event_type = message.get("type")
        event_data = message.get("data", {})
        
        logger.info(f"收到事件: {event_type} from {client_id}")
        
        try:
            # 根据事件类型路由到对应处理器
            if event_type == EventTypes.CONVERSATION_START:
                await self.handle_conversation_start(client_id, event_data)
            elif event_type == EventTypes.MESSAGE_START:
                await self.handle_message_start(client_id, event_data)
            elif event_type == EventTypes.AUDIO_STREAM:
                await self.handle_audio_stream(client_id, event_data)
            elif event_type == EventTypes.MESSAGE_END:
                await self.handle_message_end(client_id, event_data)
            elif event_type == EventTypes.MANUAL_GENERATE:
                await self.handle_manual_generate(client_id, event_data)
            elif event_type == EventTypes.USER_MODIFICATION:
                await self.handle_user_modification(client_id, event_data)
            elif event_type == EventTypes.USER_SELECTED_RESPONSE:
                await self.handle_user_selected_response(client_id, event_data)
            elif event_type == EventTypes.SCENARIO_SUPPLEMENT:
                await self.handle_scenario_supplement(client_id, event_data)
            elif event_type == EventTypes.RESPONSE_COUNT_UPDATE:
                await self.handle_response_count_update(client_id, event_data)
            elif event_type == EventTypes.CONVERSATION_END:
                await self.handle_conversation_end(client_id, event_data)
            else:
                await self.send_error(
                    client_id,
                    ErrorCodes.INVALID_EVENT_TYPE,
                    f"未知的事件类型: {event_type}"
                )
        
        except ValidationError as e:
            await self.send_error(
                client_id,
                ErrorCodes.INVALID_EVENT_DATA,
                "事件数据验证失败",
                str(e)
            )
        except Exception as e:
            logger.error(f"处理事件 {event_type} 时发生错误: {e}")
            await self.send_error(
                client_id,
                ErrorCodes.INTERNAL_ERROR,
                "处理事件时发生错误",
                str(e)
            )
    
    # ===============================
    # 具体事件处理器
    # ===============================
    
    async def handle_conversation_start(self, client_id: str, event_data: Dict[str, Any]):
        """处理对话开始事件"""
        event = ConversationStartEvent(type="conversation_start", data=event_data)
        
        # 创建新会话
        session_id = str(uuid.uuid4())
        session = self.session_manager.create_session(
            session_id=session_id,
            scenario_description=event.data.scenario_description,
            response_count=event.data.response_count
        )
        
        # 记录历史消息（如果有）
        if event.data.history_messages:
            logger.info(f"记录历史消息: {session_id}, 共 {len(event.data.history_messages)} 条")
            for history_msg in event.data.history_messages:
                # 使用前端提供的消息ID
                self.session_manager.get_session(session_id).add_message(
                    message_id=history_msg.message_id,
                    sender=history_msg.sender,
                    content=history_msg.content,
                    is_user_selected=False
                )
        
        # 发送会话创建确认
        await self.send_session_created(client_id, session_id)
        
        # 如果有历史消息或情景描述，触发意见生成
        if event.data.history_messages or event.data.scenario_description:
            if self.request_manager:
                request_id = await self.request_manager.generate_opinion_suggestions(session_id)
                if request_id:
                    logger.info(f"对话开始后自动触发意见生成: {session_id}, 请求ID: {request_id}")
        
        logger.info(f"会话创建: {session_id}")
    
    async def handle_message_start(self, client_id: str, event_data: Dict[str, Any]):
        """处理消息开始事件"""
        event = MessageStartEvent(type="message_start", data=event_data)
        
        session_id = event.data.session_id
        sender = event.data.sender
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 取消所有未完成的LLM请求
        if self.request_manager:
            cancelled_count = await self.request_manager.cancel_all_requests(session_id)
            if cancelled_count > 0:
                logger.info(f"消息开始时取消了 {cancelled_count} 个未完成的LLM请求: {session_id}")
        
        # 开始新消息
        temp_message_id = self.session_manager.start_message(session_id, sender)
        
        # 启动STT音频流处理
        if self.stt_service:
            success = await self.stt_service.start_stream_processing(session_id)
            if not success:
                await self.send_error(
                    client_id,
                    ErrorCodes.STT_SERVICE_ERROR,
                    "启动音频流处理失败",
                    session_id=session_id
                )
                return
            logger.info(f"已启动音频流处理: {session_id}")
        
        # 更新状态
        await self.send_status_update(session_id, "recording_message", "开始录制消息")
        
        logger.info(f"消息开始: {session_id}, 发送者: {sender}, 临时ID: {temp_message_id}")
    
    async def handle_audio_stream(self, client_id: str, event_data: Dict[str, Any]):
        """处理音频流事件"""
        event = AudioStreamEvent(type="audio_stream", data=event_data)
        
        session_id = event.data.session_id
        audio_chunk = event.data.audio_chunk
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # TODO: 处理音频数据
        if self.stt_service:
            await self.stt_service.process_audio_chunk(session_id, audio_chunk)
        
        logger.debug(f"音频流处理: {session_id}, 数据长度: {len(audio_chunk)}")
    
    async def handle_message_end(self, client_id: str, event_data: Dict[str, Any]):
        """处理消息结束事件"""
        event = MessageEndEvent(type="message_end", data=event_data)
        
        session_id = event.data.session_id
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 更新状态
        await self.send_status_update(session_id, "processing_stt", "处理语音转文字")
        
        # TODO: 完成STT转录
        content = "测试转录内容"  # 临时内容
        if self.stt_service:
            content = await self.stt_service.get_final_transcription(session_id)
        
        # 结束消息并获取正式ID
        message_id = self.session_manager.end_message(session_id, content)
        session = self.session_manager.get_session(session_id)
        
        # 发送消息记录确认
        await self.send_message_recorded(
            session_id, 
            message_id, 
            content, 
            session.current_message_sender or "unknown"
        )
        
        # 自动触发意见生成
        await self.send_status_update(session_id, "generating_opinions", "生成意见建议")
        
        # TODO: 触发意见生成请求
        if self.request_manager:
            await self.request_manager.generate_opinion_suggestions(session_id)
        
        logger.info(f"消息结束: {session_id}, 正式ID: {message_id}")
    
    async def handle_manual_generate(self, client_id: str, event_data: Dict[str, Any]):
        """处理手动触发生成回答事件"""
        event = ManualGenerateEvent(type="manual_generate", data=event_data)
        
        session_id = event.data.session_id
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 更新会话数据
        if event.data.focused_message_ids:
            self.session_manager.set_focused_messages(session_id, event.data.focused_message_ids)
        
        if event.data.user_opinion:
            self.session_manager.set_user_opinion(session_id, event.data.user_opinion)
        
        # 更新状态
        await self.send_status_update(session_id, "generating_response", "生成回答建议")
        
        # TODO: 触发回答生成请求
        if self.request_manager:
            await self.request_manager.generate_response_suggestions(session_id)
        
        logger.info(f"手动触发生成: {session_id}")
    
    async def handle_user_modification(self, client_id: str, event_data: Dict[str, Any]):
        """处理用户修改建议事件"""
        event = UserModificationEvent(type="user_modification", data=event_data)
        
        session_id = event.data.session_id
        modification = event.data.modification
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 添加修改建议
        self.session_manager.add_modification(session_id, modification)
        
        # 立即取消所有进行中的请求并重新生成回答
        if self.request_manager:
            await self.request_manager.cancel_all_requests(session_id)
        
        # 更新状态
        await self.send_status_update(session_id, "generating_response", "基于修改建议生成新回答")
        
        # TODO: 触发新的回答生成请求
        if self.request_manager:
            await self.request_manager.generate_response_suggestions(session_id)
        
        logger.info(f"用户修改建议: {session_id}, 修改: {modification}")
    
    async def handle_user_selected_response(self, client_id: str, event_data: Dict[str, Any]):
        """处理用户选择回答事件"""
        event = UserSelectedResponseEvent(type="user_selected_response", data=event_data)
        
        session_id = event.data.session_id
        selected_content = event.data.selected_content
        sender = event.data.sender
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 将用户选择的回答记录为新消息
        message_id = self.session_manager.add_user_selected_message(
            session_id, selected_content, sender
        )
        
        # 发送消息记录确认
        await self.send_message_recorded(session_id, message_id, selected_content, sender)
        
        logger.info(f"用户选择回答: {session_id}, 消息ID: {message_id}")
    
    async def handle_scenario_supplement(self, client_id: str, event_data: Dict[str, Any]):
        """处理情景补充事件"""
        event = ScenarioSupplementEvent(type="scenario_supplement", data=event_data)
        
        session_id = event.data.session_id
        supplement = event.data.supplement
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 更新情景描述
        self.session_manager.update_scenario(session_id, supplement)
        
        logger.info(f"情景补充: {session_id}")
    
    async def handle_response_count_update(self, client_id: str, event_data: Dict[str, Any]):
        """处理回答数量修改事件"""
        event = ResponseCountUpdateEvent(type="response_count_update", data=event_data)
        
        session_id = event.data.session_id
        response_count = event.data.response_count
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 更新回答数量
        self.session_manager.update_response_count(session_id, response_count)
        
        logger.info(f"回答数量更新: {session_id}, 新数量: {response_count}")
    
    async def handle_conversation_end(self, client_id: str, event_data: Dict[str, Any]):
        """处理对话结束事件"""
        event = ConversationEndEvent(type="conversation_end", data=event_data)
        
        session_id = event.data.session_id
        
        # 验证会话存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        # 取消所有进行中的请求
        if self.request_manager:
            await self.request_manager.cancel_all_requests(session_id)
        
        # 销毁会话
        self.session_manager.destroy_session(session_id)
        
        logger.info(f"对话结束: {session_id}")
    
    # ===============================
    # 发送事件的便捷方法
    # ===============================
    
    async def send_session_created(self, client_id: str, session_id: str):
        """发送会话创建确认事件"""
        event = SessionCreatedEvent(
            type="session_created",
            data=SessionCreatedData(session_id=session_id)
        )
        await self.send_event(client_id, event)
    
    async def send_message_recorded(self, session_id: str, message_id: str, content: str, sender: str):
        """发送消息记录确认事件"""
        # 找到对应的客户端
        for client_id in self.active_connections:
            event = MessageRecordedEvent(
                type="message_recorded",
                data=MessageRecordedData(
                    session_id=session_id,
                    message_id=message_id,
                    content=content,
                    sender=sender
                )
            )
            await self.send_event(client_id, event)
    
    async def send_opinion_suggestions(self, session_id: str, suggestions: list, request_id: str = None):
        """发送意见建议响应事件"""
        for client_id in self.active_connections:
            event = OpinionSuggestionsEvent(
                type="opinion_suggestions",
                data=OpinionSuggestionsData(
                    session_id=session_id,
                    suggestions=suggestions,
                    request_id=request_id
                )
            )
            await self.send_event(client_id, event)
    
    async def send_llm_response(self, session_id: str, suggestions: list, request_id: str = None):
        """发送LLM回答响应事件"""
        for client_id in self.active_connections:
            event = LLMResponseEvent(
                type="llm_response",
                data=LLMResponseData(
                    session_id=session_id,
                    suggestions=suggestions,
                    request_id=request_id
                )
            )
            await self.send_event(client_id, event)
    
    async def send_status_update(self, session_id: str, status: str, message: str = None):
        """发送状态更新事件"""
        for client_id in self.active_connections:
            event = StatusUpdateEvent(
                type="status_update",
                data=StatusUpdateData(
                    session_id=session_id,
                    status=status,
                    message=message
                )
            )
            await self.send_event(client_id, event)
    
    async def send_error(self, client_id: str, error_code: str, message: str, details: str = None, session_id: str = None):
        """发送错误事件"""
        event = ErrorEvent(
            type="error",
            data=ErrorData(
                session_id=session_id,
                error_code=error_code,
                message=message,
                details=details
            )
        )
        await self.send_event(client_id, event)