"""
并发请求管理器
处理LLM请求的竞争、取消和优先级管理
"""
import asyncio
import uuid
import logging
from typing import Dict, Optional, Any, List
from datetime import datetime
from enum import Enum

from app.models.session import RequestInfo
from app.services.session_manager import SessionManager
from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


class RequestType(str, Enum):
    """请求类型枚举"""
    OPINION_PREDICTION = "opinion_prediction"  # 意见预测请求
    RESPONSE = "response"  # 回答生成请求


class RequestStatus(str, Enum):
    """请求状态枚举"""
    PENDING = "pending"    # 等待处理
    RUNNING = "running"    # 正在处理
    COMPLETED = "completed"  # 已完成
    CANCELLED = "cancelled"  # 已取消
    FAILED = "failed"      # 失败


class LLMRequestManager:
    """LLM请求管理器"""
    
    def __init__(self, session_manager: SessionManager, llm_service: LLMService, websocket_handler=None):
        self.session_manager = session_manager
        self.llm_service = llm_service
        self.websocket_handler = websocket_handler
        
        # 请求跟踪
        self.response_requests: Dict[str, asyncio.Task] = {}  # session_id -> task
        self.opinion_prediction_requests: Dict[str, asyncio.Task] = {}  # session_id -> task
        self.all_requests: Dict[str, RequestInfo] = {}  # request_id -> request_info
        
        # 统计信息
        self.stats = {
            "total_requests": 0,
            "completed_requests": 0,
            "cancelled_requests": 0,
            "failed_requests": 0
        }
    
    def set_websocket_handler(self, websocket_handler):
        """设置WebSocket处理器"""
        self.websocket_handler = websocket_handler
    
    # ===============================
    # 回答生成请求管理
    # ===============================
    
    async def generate_response_suggestions(
        self, 
        session_id: str, 
        focused_message_ids: Optional[List[str]] = None,
        user_opinion: Optional[str] = None,
        user_corpus: Optional[str] = None,
        user_background: Optional[str] = None,
        user_preferences: Optional[str] = None,
        user_recent_experiences: Optional[str] = None,
    ) -> Optional[str]:
        """
        生成回答建议（手动触发或修改建议触发）
        
        Args:
            session_id: 会话ID
            focused_message_ids: 聚焦消息ID列表
            user_opinion: 用户意见
            user_corpus: 用户语料库
            user_background: 用户背景信息
            user_preferences: 用户偏好
            user_recent_experiences: 用户最近经历
            
        Returns:
            Optional[str]: 请求ID，如果创建失败则返回None
        """
        try:
            # 如果传入了用户上下文，先记录在会话中，确保后续请求也能复用
            if any([user_corpus, user_background, user_preferences, user_recent_experiences]):
                self.session_manager.update_user_context(
                    session_id=session_id,
                    user_corpus=user_corpus,
                    user_background=user_background,
                    user_preferences=user_preferences,
                    user_recent_experiences=user_recent_experiences,
                )
            if user_opinion:
                self.session_manager.set_user_opinion(session_id, user_opinion)

            # 手动触发优先级最高，取消所有进行中的请求
            await self.cancel_all_requests(session_id)
            
            # 创建新的请求
            request_id = str(uuid.uuid4())
            request_info = RequestInfo(
                id=request_id,
                session_id=session_id,
                request_type=RequestType.RESPONSE,
                status=RequestStatus.PENDING
            )
            
            self.all_requests[request_id] = request_info
            self.stats["total_requests"] += 1
            
            # 创建异步任务
            task = asyncio.create_task(
                self._execute_response_generation(
                    session_id=session_id,
                    request_id=request_id,
                    focused_message_ids=focused_message_ids,
                )
            )
            self.response_requests[session_id] = task
            
            # 更新会话中的活动请求ID
            self.session_manager.set_active_response_request(session_id, request_id)
            
            logger.info(f"创建回答生成请求: {session_id}, 请求ID: {request_id}")
            
            return request_id
            
        except Exception as e:
            logger.error(f"创建回答生成请求失败 {session_id}: {e}")
            return None
    
    async def _execute_response_generation(
        self, 
        session_id: str, 
        request_id: str,
        focused_message_ids: Optional[List[str]] = None,
    ):
        """执行回答生成"""
        try:
            # 更新请求状态
            self._update_request_status(request_id, RequestStatus.RUNNING)
            
            # 获取会话
            session = self.session_manager.get_session(session_id)
            if not session:
                raise ValueError(f"会话不存在: {session_id}")
            
            # 调用LLM服务
            count = session.response_count
            user_context = {
                "corpus": session.user_corpus,
                "background": session.user_background,
                "preferences": session.user_preferences,
                "recent_experiences": session.user_recent_experiences,
            }
            suggestions = await self.llm_service.generate_responses(
                session=session, 
                count=count,
                focused_message_ids=focused_message_ids,
                user_opinion=session.user_opinion,
                user_context=user_context,
            )
            
            # 检查是否被取消
            if request_id not in self.all_requests or \
               self.all_requests[request_id].status == RequestStatus.CANCELLED:
                logger.info(f"回答生成请求已取消: {request_id}")
                return
            
            # 发送结果
            if self.websocket_handler:
                await self.websocket_handler.send_llm_response(
                    session_id, suggestions, request_id
                )
            
            # 更新请求状态
            self._update_request_status(request_id, RequestStatus.COMPLETED)
            self.stats["completed_requests"] += 1
            
            logger.info(f"回答生成完成: {request_id}, 生成了 {len(suggestions)} 个建议")
            
        except asyncio.CancelledError:
            self._update_request_status(request_id, RequestStatus.CANCELLED)
            self.stats["cancelled_requests"] += 1
            logger.info(f"回答生成请求被取消: {request_id}")
            
        except Exception as e:
            self._update_request_status(request_id, RequestStatus.FAILED, str(e))
            self.stats["failed_requests"] += 1
            logger.error(f"回答生成失败 {request_id}: {e}")
            
        finally:
            # 清理
            if session_id in self.response_requests:
                del self.response_requests[session_id]
            self.session_manager.clear_active_response_request(session_id)
    
    async def cancel_response_requests(self, session_id: str) -> int:
        """
        取消指定会话的回答生成请求
        
        Args:
            session_id: 会话ID
            
        Returns:
            int: 取消的请求数量
        """
        cancelled_count = 0
        
        if session_id in self.response_requests:
            task = self.response_requests[session_id]
            if not task.done():
                task.cancel()
                cancelled_count += 1
                logger.info(f"取消回答生成请求: {session_id}")
            
            del self.response_requests[session_id]
        
        # 清理会话中的活动请求ID
        self.session_manager.clear_active_response_request(session_id)
        
        return cancelled_count

    # ===============================
    # 意见预测请求管理
    # ===============================

    async def generate_opinion_prediction(
        self, 
        session_id: str,
        last_message_content: str
    ) -> Optional[str]:
        """
        生成意见预测
        
        Args:
            session_id: 会话ID
            last_message_content: 用户最后选择的消息内容
            
        Returns:
            Optional[str]: 请求ID，如果创建失败则返回None
        """
        try:
            # 意见预测请求优先级较低，不取消其他请求
            # 但新的预测请求会取消旧的预测请求
            await self.cancel_opinion_prediction_requests(session_id)

            request_id = str(uuid.uuid4())
            request_info = RequestInfo(
                id=request_id,
                session_id=session_id,
                request_type=RequestType.OPINION_PREDICTION,
                status=RequestStatus.PENDING
            )
            self.all_requests[request_id] = request_info
            self.stats["total_requests"] += 1

            task = asyncio.create_task(
                self._execute_opinion_prediction(session_id, request_id, last_message_content)
            )
            self.opinion_prediction_requests[session_id] = task
            
            logger.info(f"创建意见预测请求: {session_id}, 请求ID: {request_id}")
            return request_id

        except Exception as e:
            logger.error(f"创建意见预测请求失败 {session_id}: {e}")
            return None

    async def _execute_opinion_prediction(
        self, 
        session_id: str, 
        request_id: str,
        last_message_content: str
    ):
        """执行意见预测"""
        try:
            self._update_request_status(request_id, RequestStatus.RUNNING)
            
            session = self.session_manager.get_session(session_id)
            if not session:
                raise ValueError(f"会话不存在: {session_id}")

            prediction = await self.llm_service.generate_opinion_prediction(
                session=session, 
                last_message_content=last_message_content
            )

            if request_id not in self.all_requests or \
               self.all_requests[request_id].status == RequestStatus.CANCELLED:
                logger.info(f"意见预测请求已取消: {request_id}")
                return

            if self.websocket_handler and prediction:
                await self.websocket_handler.send_opinion_prediction(
                    session_id, prediction, request_id
                )
            
            self._update_request_status(request_id, RequestStatus.COMPLETED)
            self.stats["completed_requests"] += 1
            logger.info(f"意见预测完成: {request_id}")

        except asyncio.CancelledError:
            self._update_request_status(request_id, RequestStatus.CANCELLED)
            self.stats["cancelled_requests"] += 1
            logger.info(f"意见预测请求被取消: {request_id}")

        except Exception as e:
            self._update_request_status(request_id, RequestStatus.FAILED, str(e))
            self.stats["failed_requests"] += 1
            logger.error(f"意见预测失败 {request_id}: {e}")

        finally:
            if session_id in self.opinion_prediction_requests:
                del self.opinion_prediction_requests[session_id]

    async def cancel_opinion_prediction_requests(self, session_id: str) -> int:
        """
        取消指定会话的意见预测请求
        """
        cancelled_count = 0
        if session_id in self.opinion_prediction_requests:
            task = self.opinion_prediction_requests[session_id]
            if not task.done():
                task.cancel()
                cancelled_count += 1
                logger.info(f"取消意见预测请求: {session_id}")
            del self.opinion_prediction_requests[session_id]
        return cancelled_count
    
    # ===============================
    # 统一请求管理
    # ===============================
    
    async def cancel_all_requests(self, session_id: str) -> int:
        """
        取消指定会话的所有进行中请求
        
        Args:
            session_id: 会话ID
            
        Returns:
            int: 取消的请求总数
        """
        total_cancelled = 0
        
        # 取消回答生成请求
        total_cancelled += await self.cancel_response_requests(session_id)
        
        # 取消意见预测请求
        total_cancelled += await self.cancel_opinion_prediction_requests(session_id)
        
        logger.info(f"取消会话所有请求: {session_id}, 共取消 {total_cancelled} 个请求")
        
        return total_cancelled
    
    async def cancel_all_requests_global(self) -> int:
        """
        取消所有进行中的请求
        
        Returns:
            int: 取消的请求总数
        """
        total_cancelled = 0
        
        # 取消所有回答生成请求
        session_ids = list(self.response_requests.keys())
        for session_id in session_ids:
            total_cancelled += await self.cancel_response_requests(session_id)
        
        logger.info(f"取消所有请求，共取消 {total_cancelled} 个请求")
        
        return total_cancelled
    
    def _update_request_status(self, request_id: str, status: RequestStatus, error_message: str = None):
        """更新请求状态"""
        if request_id in self.all_requests:
            request_info = self.all_requests[request_id]
            request_info.status = status.value
            request_info.error_message = error_message
            
            if status in [RequestStatus.COMPLETED, RequestStatus.CANCELLED, RequestStatus.FAILED]:
                request_info.completed_at = datetime.utcnow()
    
    # ===============================
    # 查询和统计
    # ===============================
    
    def get_request_info(self, request_id: str) -> Optional[RequestInfo]:
        """
        获取请求信息
        
        Args:
            request_id: 请求ID
            
        Returns:
            Optional[RequestInfo]: 请求信息
        """
        return self.all_requests.get(request_id)
    
    def get_session_requests(self, session_id: str) -> List[RequestInfo]:
        """
        获取指定会话的所有请求
        
        Args:
            session_id: 会话ID
            
        Returns:
            List[RequestInfo]: 请求信息列表
        """
        return [
            req for req in self.all_requests.values()
            if req.session_id == session_id
        ]
    
    def get_active_requests(self) -> List[RequestInfo]:
        """
        获取所有活动请求
        
        Returns:
            List[RequestInfo]: 活动请求列表
        """
        return [
            req for req in self.all_requests.values()
            if req.status in [RequestStatus.PENDING.value, RequestStatus.RUNNING.value]
        ]
    
    def get_request_statistics(self) -> Dict[str, Any]:
        """
        获取请求统计信息
        
        Returns:
            Dict[str, Any]: 统计信息
        """
        active_response_count = len(self.response_requests)
        active_opinion_prediction_count = len(self.opinion_prediction_requests)
        
        return {
            "total_requests": self.stats["total_requests"],
            "completed_requests": self.stats["completed_requests"],
            "cancelled_requests": self.stats["cancelled_requests"],
            "failed_requests": self.stats["failed_requests"],
            "active_response_requests": active_response_count,
            "active_opinion_prediction_requests": active_opinion_prediction_count,
            "total_active_requests": active_response_count + active_opinion_prediction_count,
            "success_rate": (
                self.stats["completed_requests"] / self.stats["total_requests"]
                if self.stats["total_requests"] > 0 else 0
            )
        }
    
    def is_session_busy(self, session_id: str) -> bool:
        """
        检查会话是否有活动请求
        
        Args:
            session_id: 会话ID
            
        Returns:
            bool: 是否忙碌
        """
        return session_id in self.response_requests or session_id in self.opinion_prediction_requests
    
    def get_session_request_status(self, session_id: str) -> Dict[str, Any]:
        """
        获取会话的请求状态
        
        Args:
            session_id: 会话ID
            
        Returns:
            Dict[str, Any]: 会话请求状态
        """
        has_response_request = session_id in self.response_requests
        
        response_request_id = None
        
        if has_response_request:
            response_request_id = self.session_manager.get_active_response_request(session_id)
        
        return {
            "session_id": session_id,
            "is_busy": has_response_request,
            "has_response_request": has_response_request,
            "response_request_id": response_request_id
        }
    
    # ===============================
    # 清理和维护
    # ===============================
    
    def cleanup_completed_requests(self, max_age_hours: int = 24) -> int:
        """
        清理已完成的旧请求
        
        Args:
            max_age_hours: 最大保留时间（小时）
            
        Returns:
            int: 清理的请求数量
        """
        from datetime import timedelta
        
        cutoff_time = datetime.utcnow() - timedelta(hours=max_age_hours)
        expired_requests = []
        
        for request_id, request_info in self.all_requests.items():
            if (request_info.completed_at and 
                request_info.completed_at < cutoff_time and
                request_info.status in [
                    RequestStatus.COMPLETED.value,
                    RequestStatus.CANCELLED.value,
                    Request.FAILED.value
                ]):
                expired_requests.append(request_id)
        
        for request_id in expired_requests:
            del self.all_requests[request_id]
        
        if expired_requests:
            logger.info(f"清理过期请求: {len(expired_requests)} 个")
        
        return len(expired_requests)
    
    async def shutdown(self):
        """关闭请求管理器"""
        try:
            # 取消所有进行中的请求
            cancelled_count = await self.cancel_all_requests_global()
            
            # 清理所有请求记录
            self.all_requests.clear()
            
            logger.info(f"请求管理器已关闭，取消了 {cancelled_count} 个请求")
            
        except Exception as e:
            logger.error(f"请求管理器关闭时发生错误: {e}")
    
    async def health_check(self) -> Dict[str, Any]:
        """
        健康检查
        
        Returns:
            Dict[str, Any]: 健康状态信息
        """
        stats = self.get_request_statistics()
        
        return {
            "service": "RequestManager",
            "status": "healthy",
            "statistics": stats,
            "memory_usage": {
                "total_requests_in_memory": len(self.all_requests),
                "active_response_tasks": len(self.response_requests)
            }
        }
