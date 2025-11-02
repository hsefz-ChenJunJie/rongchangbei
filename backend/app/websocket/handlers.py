"""
WebSocket事件处理器
"""
import json
import uuid
import logging
import asyncio
import time
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from fastapi import WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from app.models.events import (
    EventTypes, ErrorCodes,
    IncomingEvent, OutgoingEvent,
    ConversationStartEvent, MessageStartEvent, AudioStreamEvent, MessageEndEvent,
    ManualGenerateEvent, UserModificationEvent, UserSelectedResponseEvent,
    ScenarioSupplementEvent, ResponseCountUpdateEvent, ConversationEndEvent,
    SessionResumeEvent, GetMessageHistoryEvent,
    SessionCreatedEvent, MessageRecordedEvent,
    LLMResponseEvent, StatusUpdateEvent, ErrorEvent, SessionRestoredEvent,
    MessageHistoryResponseEvent, OpinionPredictionEvent,
    SessionCreatedData, MessageRecordedData,
    LLMResponseData, StatusUpdateData, ErrorData, SessionRestoredData,
    MessageHistoryResponseData, MessageHistoryItem, OpinionPredictionData
)

logger = logging.getLogger(__name__)


class WebSocketHandler:
    """WebSocket事件处理器"""
    
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.connection_info: Dict[str, Dict[str, Any]] = {}  # 连接状态信息
        self.session_manager = None  # 将在初始化时注入
        self.stt_service = None      # 将在初始化时注入
        self.llm_service = None      # 将在初始化时注入
        self.request_manager = None  # 将在初始化时注入
        self.persistence_manager = None  # 会话持久化管理器
        self.heartbeat_task = None   # 心跳检查任务
        self.heartbeat_interval = 30  # 心跳间隔（秒）
        self.connection_timeout = 300  # 连接超时时间（秒）
    
    def set_services(self, session_manager, stt_service=None, llm_service=None, request_manager=None, persistence_manager=None):
        """注入服务依赖"""
        self.session_manager = session_manager
        self.stt_service = stt_service
        self.llm_service = llm_service
        self.request_manager = request_manager
        self.persistence_manager = persistence_manager
    
    # ===============================
    # 连接管理
    # ===============================
    
    async def connect(self, websocket: WebSocket, client_id: str):
        """接受WebSocket连接"""
        await websocket.accept()
        self.active_connections[client_id] = websocket
        
        # 记录连接信息
        self.connection_info[client_id] = {
            "connected_at": datetime.utcnow(),
            "last_activity": datetime.utcnow(),
            "message_count": 0,
            "error_count": 0,
            "session_ids": [],
            "is_healthy": True
        }
        
        # 启动心跳检查（如果还没有启动）
        if self.heartbeat_task is None or self.heartbeat_task.done():
            self.heartbeat_task = asyncio.create_task(self._heartbeat_loop())
        
        logger.info(f"WebSocket连接建立: {client_id}")
    
    async def disconnect(self, client_id: str):
        """断开WebSocket连接"""
        if client_id in self.active_connections:
            del self.active_connections[client_id]
        
        # 处理相关会话的断连清理
        if client_id in self.connection_info:
            info = self.connection_info[client_id]
            session_ids = info.get("session_ids", [])
            
            for session_id in session_ids:
                await self._handle_session_disconnect(session_id)
        
        # 清理连接信息并记录统计
        if client_id in self.connection_info:
            info = self.connection_info[client_id]
            duration = (datetime.utcnow() - info["connected_at"]).total_seconds()
            logger.info(
                f"WebSocket连接断开: {client_id}, "
                f"持续时间: {duration:.1f}秒, "
                f"消息数: {info['message_count']}, "
                f"错误数: {info['error_count']}"
            )
            del self.connection_info[client_id]
    
    async def send_event(self, client_id: str, event: OutgoingEvent):
        """发送事件到客户端"""
        if client_id in self.active_connections:
            websocket = self.active_connections[client_id]
            try:
                # 直接尝试发送事件，让WebSocket自然抛出异常来处理断开的连接
                event_dict = event.dict()
                await websocket.send_text(json.dumps(event_dict, ensure_ascii=False))
                logger.debug(f"发送事件到 {client_id}: {event.type}")
                
                # 更新连接活动时间
                if client_id in self.connection_info:
                    self.connection_info[client_id]["last_activity"] = datetime.utcnow()
                    
            except Exception as e:
                logger.error(f"发送事件失败 {client_id}: {e}")
                
                # 更新错误计数
                if client_id in self.connection_info:
                    self.connection_info[client_id]["error_count"] += 1
                    self.connection_info[client_id]["is_healthy"] = False
                
                await self.disconnect(client_id)
        else:
            logger.warning(f"尝试向不存在的连接发送事件: {client_id}")
    
    # ===============================
    # 事件处理主循环
    # ===============================
    
    async def handle_connection(self, websocket: WebSocket, client_id: str):
        """处理WebSocket连接"""
        await self.connect(websocket, client_id)
        
        try:
            while True:
                try:
                    # 接收消息（带超时）
                    data = await asyncio.wait_for(
                        websocket.receive_text(), 
                        timeout=self.connection_timeout
                    )
                    
                    # 更新活动时间和消息计数
                    if client_id in self.connection_info:
                        info = self.connection_info[client_id]
                        info["last_activity"] = datetime.utcnow()
                        info["message_count"] += 1
                    
                    try:
                        message = json.loads(data)
                        await self.handle_event(client_id, message)
                    except json.JSONDecodeError as e:
                        if client_id in self.connection_info:
                            self.connection_info[client_id]["error_count"] += 1
                        await self.send_error(
                            client_id, 
                            ErrorCodes.INVALID_EVENT_DATA,
                            "无效的JSON格式",
                            str(e)
                        )
                    except Exception as e:
                        if client_id in self.connection_info:
                            self.connection_info[client_id]["error_count"] += 1
                        logger.error(f"处理事件时发生错误: {e}")
                        await self.send_error(
                            client_id,
                            ErrorCodes.INTERNAL_ERROR,
                            "服务器内部错误",
                            str(e)
                        )
                        
                except asyncio.TimeoutError:
                    logger.warning(f"WebSocket连接超时: {client_id}")
                    break
                except WebSocketDisconnect:
                    logger.info(f"WebSocket客户端主动断开: {client_id}")
                    break
                    
        except Exception as e:
            logger.error(f"WebSocket连接错误 {client_id}: {e}")
        finally:
            await self.disconnect(client_id)
    
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
            elif event_type == EventTypes.SESSION_RESUME:
                await self.handle_session_resume(client_id, event_data)
            elif event_type == EventTypes.GET_MESSAGE_HISTORY:
                await self.handle_get_message_history(client_id, event_data)
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
        
        # 设置历史消息（如果有）
        if event.data.history_messages:
            logger.info(f"设置历史消息: {session_id}, 共 {len(event.data.history_messages)} 条")
            history_msgs = [
                {
                    "message_id": history_msg.message_id,
                    "sender": history_msg.sender,
                    "content": history_msg.content
                } for history_msg in event.data.history_messages
            ]
            self.session_manager.get_session(session_id).set_history_messages(history_msgs)
        
        # 记录连接与会话的关联
        if client_id in self.connection_info:
            self.connection_info[client_id]["session_ids"].append(session_id)
        
        # 发送会话创建确认
        await self.send_session_created(client_id, session_id)
        
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
        
        session = self.session_manager.get_session(session_id)
        
        # 检查是否正在从断连中恢复
        if session and session.is_recovering_from_disconnect:
            logger.info(f"音频流恢复中: {session_id}")
            # 清除恢复标记，现在可以正常处理音频
            session.is_recovering_from_disconnect = False
        
        # 处理音频数据
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
        
        session = self.session_manager.get_session(session_id)
        
        # 完成STT转录
        content = ""
        if self.stt_service:
            final_content = await self.stt_service.get_final_transcription(session_id)
            if final_content:
                content = final_content
        
        # 结束消息并获取正式ID
        message_id = self.session_manager.end_message(session_id, content)
        
        # 发送消息记录确认（包含消息内容）
        await self.send_message_recorded(session_id, message_id, content)
        
        # 主动保存会话（有新消息时）
        if self.persistence_manager:
            try:
                success = await self.persistence_manager.save_session(session)
                if success:
                    logger.debug(f"消息记录后会话已保存: {session_id}")
            except Exception as e:
                logger.error(f"保存会话失败 {session_id}: {e}")
        
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
        
        # 更新状态
        await self.send_status_update(session_id, "generating_response", "生成回答建议")
        
        # 触发回答生成请求
        if self.request_manager:
            await self.request_manager.generate_response_suggestions(
                session_id=session_id,
                focused_message_ids=event.data.focused_message_ids,
                user_corpus=event.data.user_corpus
            )
        
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
        await self.send_message_recorded(session_id, message_id)
        
        # 触发意见预测任务
        if self.request_manager:
            await self.request_manager.generate_opinion_prediction(
                session_id=session_id,
                last_message_content=selected_content
            )

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
        
        # 删除持久化的会话文件（正常结束）
        if self.persistence_manager:
            await self.persistence_manager.delete_session(session_id)
        
        logger.info(f"对话结束: {session_id}")
    
    async def handle_session_resume(self, client_id: str, event_data: Dict[str, Any]):
        """处理会话恢复事件"""
        event = SessionResumeEvent(type="session_resume", data=event_data)
        
        session_id = event.data.session_id
        
        # 验证持久化管理器是否可用
        if not self.persistence_manager:
            await self.send_error(
                client_id,
                ErrorCodes.INTERNAL_ERROR,
                "会话恢复功能未启用",
                session_id=session_id
            )
            return
        
        # 尝试从持久化存储加载会话
        session = await self.persistence_manager.load_session(session_id)
        
        if not session:
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在或已过期: {session_id}",
                session_id=session_id
            )
            return
        
        # 将会话恢复到内存中
        try:
            # 检查会话是否已在内存中
            if self.session_manager.session_exists(session_id):
                logger.warning(f"会话已在内存中，无需恢复: {session_id}")
            else:
                # 将会话添加到会话管理器
                self.session_manager.sessions[session_id] = session
                logger.info(f"会话已恢复到内存: {session_id}")
            
            # 记录连接与会话的关联
            if client_id in self.connection_info:
                self.connection_info[client_id]["session_ids"].append(session_id)
            
            # 发送会话恢复成功事件
            await self.send_session_restored(client_id, session)
            
            # 检查是否需要恢复录音流
            await self._check_recording_recovery(client_id, session)
            
        except Exception as e:
            logger.error(f"恢复会话失败 {session_id}: {e}")
            await self.send_error(
                client_id,
                ErrorCodes.INTERNAL_ERROR,
                f"会话恢复失败: {str(e)}",
                session_id=session_id
            )
    
    async def handle_get_message_history(self, client_id: str, event_data: Dict[str, Any]):
        """处理获取消息历史测试事件"""
        event = GetMessageHistoryEvent(type="get_message_history", data=event_data)
        
        session_id = event.data.session_id
        
        # 检查会话是否存在
        if not self.session_manager.session_exists(session_id):
            await self.send_error(
                client_id,
                ErrorCodes.SESSION_NOT_FOUND,
                f"会话不存在: {session_id}",
                session_id=session_id
            )
            return
        
        try:
            # 获取会话数据
            session = self.session_manager.get_session(session_id)
            if not session:
                await self.send_error(
                    client_id,
                    ErrorCodes.SESSION_NOT_FOUND,
                    f"无法获取会话数据: {session_id}",
                    session_id=session_id
                )
                return
            
            # 构建消息历史列表
            message_history = []
            
            # 添加历史消息（对话开始时传入的）
            if hasattr(session, 'history_messages') and session.history_messages:
                for hist_msg in session.history_messages:
                    message_history.append(MessageHistoryItem(
                        message_id=hist_msg.message_id,
                        sender=hist_msg.sender,
                        content=hist_msg.content,
                        created_at=session.created_at.isoformat() if hasattr(session, 'created_at') else datetime.utcnow().isoformat(),
                        message_type="history"
                    ))
            
            # 添加录制消息和用户选择的回答
            for message in session.messages:
                # 根据is_user_selected字段判断类型
                message_type = "selected_response" if message.is_user_selected else "recording"
                
                message_history.append(MessageHistoryItem(
                    message_id=message.id,
                    sender=message.sender,
                    content=message.content,
                    created_at=message.timestamp.isoformat(),
                    message_type=message_type
                ))
            
            # 发送消息历史响应
            await self.send_message_history_response(
                client_id, 
                session_id, 
                message_history,
                str(uuid.uuid4())  # 生成请求ID
            )
            
            logger.info(f"已发送消息历史，会话 {session_id}，消息数量: {len(message_history)}")
            
        except Exception as e:
            logger.error(f"获取消息历史失败 {session_id}: {e}")
            await self.send_error(
                client_id,
                ErrorCodes.INTERNAL_ERROR,
                f"获取消息历史失败: {str(e)}",
                session_id=session_id
            )
    
    async def _handle_session_disconnect(self, session_id: str):
        """处理会话的断连逻辑"""
        if not self.session_manager:
            logger.debug(f"会话管理器不可用，跳过断连处理: {session_id}")
            return
        
        try:
            session = self.session_manager.get_session(session_id)
            if not session:
                logger.debug(f"会话不存在，跳过断连处理: {session_id}")
                return
            
            logger.info(f"处理会话断连: {session_id}, 当前状态: {session.status}")
            
            # 1. 取消所有未完成的 LLM 请求
            if self.request_manager:
                cancelled_count = await self.request_manager.cancel_all_requests(session_id)
                if cancelled_count > 0:
                    logger.info(f"断连时取消了 {cancelled_count} 个未完成的LLM请求: {session_id}")
            
            # 2. 检查是否正在录音，如果是则特殊处理
            if session.is_recording_message():
                await self._handle_recording_disconnect(session_id, session)
            else:
                # 3. 普通断连，直接保存会话
                await self._save_session_on_disconnect(session_id)
                
        except Exception as e:
            logger.error(f"处理会话断连异常 {session_id}: {e}")

    async def _handle_recording_disconnect(self, session_id: str, session):
        """处理录音过程中的断连（累积模式）"""
        try:
            logger.info(f"检测到录音中断连，开始保护性处理: {session_id}")
            
            # 获取累积的音频数据
            accumulated_audio = None
            audio_size = 0
            
            if self.stt_service and self.stt_service.is_stream_active(session_id):
                # 获取已累积的音频数据
                accumulated_audio = self.stt_service.get_accumulated_audio(session_id)
                if accumulated_audio:
                    audio_size = len(accumulated_audio)
                    logger.info(f"保存累积音频数据: {session_id}, 大小: {audio_size} 字节")
                    
                    # 将音频数据保存到会话中
                    session.set_accumulated_audio(accumulated_audio)
                    session.set_partial_transcription(f"录音中断连，已保存 {audio_size} 字节音频", audio_size)
                else:
                    # 没有音频数据，只记录状态
                    session.set_partial_transcription("录音开始但无音频数据", 0)
            else:
                # STT服务不可用或流未激活
                session.set_partial_transcription("录音中断连，STT服务不可用", 0)
                
            # 保持 RECORDING_MESSAGE 状态，不清理临时消息状态
            # 这样重连后可以继续接收音频
            logger.info(f"保持录音状态用于重连恢复: {session_id}")
            
            # 保存会话（包含累积音频数据）
            await self._save_session_on_disconnect(session_id)
            
        except Exception as e:
            logger.error(f"处理录音断连异常 {session_id}: {e}")
            # 发生异常时也要保存会话状态
            await self._save_session_on_disconnect(session_id)
    
    async def _check_recording_recovery(self, client_id: str, session):
        """检查是否需要恢复录音流（累积模式）"""
        try:
            session_id = session.id
            
            # 检查会话是否正在录音状态
            if session.is_recording_message():
                logger.info(f"检测到需要恢复录音状态: {session_id}")
                
                # 标记正在从断连中恢复
                session.mark_recovering_from_disconnect()
                
                # 如果有部分转录内容，发送给前端
                if session.has_partial_content():
                    if session.partial_transcription:
                        await self.send_message_recorded(
                            session_id, 
                            session.current_message_id or "recovering", 
                            f"[恢复] {session.partial_transcription}"
                        )
                        logger.info(f"发送部分转录内容: {session_id}")
                
                # 重新启动音频流处理（准备接收后续音频）
                if self.stt_service:
                    # 检查是否需要重启STT流
                    if not self.stt_service.is_stream_active(session_id):
                        # 获取保存的累积音频数据
                        existing_audio = session.get_accumulated_audio()
                        
                        success = await self.stt_service.start_stream_processing(session_id, existing_audio=existing_audio)
                        if success:
                            logger.info(f"重连后重新启动音频流处理: {session_id}, 恢复音频: {len(existing_audio) if existing_audio else 0} 字节")
                        else:
                            logger.error(f"重连后启动音频流处理失败: {session_id}")
                    else:
                        logger.info(f"音频流处理仍然活动: {session_id}")
                
                # 发送状态更新，通知前端可以继续录音
                await self.send_status_update(
                    session_id, 
                    "recording_message", 
                    "已恢复录音状态，可以继续发送音频"
                )
                
                logger.info(f"录音状态恢复完成: {session_id}")
                
        except Exception as e:
            logger.error(f"检查录音恢复异常 {session.id}: {e}")
            
    async def _save_session_on_disconnect(self, session_id: str):
        """在连接断开时保存会话"""
        if not self.persistence_manager or not self.session_manager:
            logger.debug(f"持久化管理器或会话管理器不可用，跳过保存: {session_id}")
            return
        
        try:
            session = self.session_manager.get_session(session_id)
            if session and (session.messages or session.is_recording_message()):
                # 积极保存有消息内容或正在录音的会话
                logger.info(f"正在保存会话到持久化存储: {session_id}")
                success = await self.persistence_manager.save_session(session)
                if success:
                    logger.info(f"连接断开时会话已保存: {session_id} (消息数: {len(session.messages)}, 状态: {session.status})")
                else:
                    logger.error(f"连接断开时保存会话失败: {session_id}")
            else:
                logger.debug(f"会话为空或无重要数据，跳过保存: {session_id}")
        except Exception as e:
            logger.error(f"保存会话异常 {session_id}: {e}")
    
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
    
    async def send_session_restored(self, client_id: str, session):
        """发送会话恢复成功事件"""
        event = SessionRestoredEvent(
            type="session_restored",
            data=SessionRestoredData(
                session_id=session.id,
                status=session.status.value,
                message_count=len(session.messages),
                scenario_description=session.scenario_description,
                response_count=session.response_count,
                has_modifications=len(session.modifications) > 0,
                restored_at=datetime.utcnow().isoformat()
            )
        )
        await self.send_event(client_id, event)
    
    async def send_message_recorded(self, session_id: str, message_id: str, message_content: Optional[str] = None):
        """发送消息记录确认事件"""
        # 找到对应的客户端
        for client_id in self.active_connections:
            event = MessageRecordedEvent(
                type="message_recorded",
                data=MessageRecordedData(
                    session_id=session_id,
                    message_id=message_id,
                    message_content=message_content
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

    async def send_opinion_prediction(self, session_id: str, prediction: dict, request_id: str = None):
        """发送意见预测响应事件"""
        for client_id in self.active_connections:
            event = OpinionPredictionEvent(
                type="opinion_prediction_response",
                data=OpinionPredictionData(
                    session_id=session_id,
                    prediction=prediction,
                    request_id=request_id
                )
            )
            await self.send_event(client_id, event)
    
    async def send_message_history_response(self, client_id: str, session_id: str, messages: list, request_id: str = None):
        """发送消息历史响应事件（测试专用）"""
        event = MessageHistoryResponseEvent(
            type="message_history_response",
            data=MessageHistoryResponseData(
                session_id=session_id,
                messages=messages,
                total_count=len(messages),
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
    
    # ===============================
    # 连接监控和心跳管理
    # ===============================
    
    async def _heartbeat_loop(self):
        """心跳检查循环"""
        while True:
            try:
                await asyncio.sleep(self.heartbeat_interval)
                
                if not self.active_connections:
                    continue
                
                current_time = datetime.utcnow()
                stale_connections = []
                
                # 检查所有连接的活动时间
                for client_id, info in self.connection_info.items():
                    last_activity = info["last_activity"]
                    inactive_duration = (current_time - last_activity).total_seconds()
                    
                    # 如果连接长时间无活动，标记为需要清理
                    if inactive_duration > self.connection_timeout:
                        stale_connections.append(client_id)
                        logger.warning(
                            f"连接 {client_id} 长时间无活动 ({inactive_duration:.1f}秒)，准备清理"
                        )
                    elif inactive_duration > self.heartbeat_interval * 2:
                        # 检查连接状态并发送心跳
                        try:
                            websocket = self.active_connections.get(client_id)
                            if websocket and not websocket.client_state.DISCONNECTED:
                                # 使用FastAPI WebSocket的状态检查
                                try:
                                    # 发送状态更新作为心跳检测
                                    test_event = {
                                        "type": "heartbeat",
                                        "data": {"timestamp": datetime.utcnow().isoformat()}
                                    }
                                    await websocket.send_text(json.dumps(test_event))
                                    logger.debug(f"发送心跳到 {client_id}")
                                except Exception as send_error:
                                    logger.warning(f"心跳发送失败 {client_id}: {send_error}")
                                    stale_connections.append(client_id)
                            else:
                                logger.debug(f"连接已断开，标记为过期: {client_id}")
                                stale_connections.append(client_id)
                        except Exception as e:
                            logger.warning(f"心跳检查失败 {client_id}: {e}")
                            stale_connections.append(client_id)
                
                # 清理无效连接
                for client_id in stale_connections:
                    try:
                        websocket = self.active_connections.get(client_id)
                        if websocket:
                            await websocket.close()
                    except Exception as e:
                        logger.debug(f"关闭无效连接时出错 {client_id}: {e}")
                    finally:
                        await self.disconnect(client_id)
                
                if stale_connections:
                    logger.info(f"清理了 {len(stale_connections)} 个无效连接")
                    
            except asyncio.CancelledError:
                logger.info("心跳检查任务已停止")
                break
            except Exception as e:
                logger.error(f"心跳检查出错: {e}")
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """获取连接统计信息"""
        current_time = datetime.utcnow()
        total_connections = len(self.active_connections)
        healthy_connections = 0
        total_messages = 0
        total_errors = 0
        
        connection_details = []
        
        for client_id, info in self.connection_info.items():
            duration = (current_time - info["connected_at"]).total_seconds()
            last_activity_age = (current_time - info["last_activity"]).total_seconds()
            
            if info["is_healthy"] and last_activity_age < self.connection_timeout:
                healthy_connections += 1
            
            total_messages += info["message_count"]
            total_errors += info["error_count"]
            
            connection_details.append({
                "client_id": client_id,
                "connected_duration": round(duration, 1),
                "last_activity_age": round(last_activity_age, 1),
                "message_count": info["message_count"],
                "error_count": info["error_count"],
                "is_healthy": info["is_healthy"],
                "session_count": len(info["session_ids"])
            })
        
        return {
            "total_connections": total_connections,
            "healthy_connections": healthy_connections,
            "total_messages": total_messages,
            "total_errors": total_errors,
            "error_rate": round(total_errors / max(total_messages, 1) * 100, 2),
            "heartbeat_interval": self.heartbeat_interval,
            "connection_timeout": self.connection_timeout,
            "connections": connection_details
        }
    
    async def shutdown(self):
        """优雅关闭WebSocket处理器"""
        # 停止心跳任务
        if self.heartbeat_task and not self.heartbeat_task.done():
            self.heartbeat_task.cancel()
            try:
                await self.heartbeat_task
            except asyncio.CancelledError:
                pass
        
        # 关闭所有连接
        client_ids = list(self.active_connections.keys())
        for client_id in client_ids:
            try:
                websocket = self.active_connections[client_id]
                await websocket.close()
            except Exception as e:
                logger.debug(f"关闭连接时出错 {client_id}: {e}")
            finally:
                await self.disconnect(client_id)
        
        logger.info("WebSocket处理器已关闭")