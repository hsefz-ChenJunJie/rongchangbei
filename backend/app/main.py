"""
FastAPI应用入口文件
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import json
import time
from datetime import datetime
from typing import Dict, Any

from config.settings import settings
from app.api.health import router as health_router
from app.services.session_manager import SessionManager
from app.services.stt_service import create_stt_service
from app.services.llm_service import create_llm_service
from app.services.request_manager import LLMRequestManager
from app.websocket.handlers import WebSocketHandler

# 配置日志
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 全局服务实例
session_manager = None
stt_service = None
llm_service = None
request_manager = None
websocket_handler = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    应用生命周期管理器
    """
    global session_manager, stt_service, llm_service, request_manager, websocket_handler
    
    # 启动时初始化
    logger.info("AI对话应用后端启动中...")
    
    try:
        # 初始化会话管理器
        session_manager = SessionManager()
        logger.info("会话管理器初始化完成")
        
        # 初始化STT服务
        try:
            stt_service = create_stt_service()
            if await stt_service.initialize():
                logger.info("STT服务初始化完成")
            else:
                logger.warning("STT服务初始化失败，继续运行")
        except Exception as e:
            logger.error(f"STT服务创建失败: {e}，使用备用Mock服务")
            from app.services.stt_service import STTService
            stt_service = STTService()
            await stt_service.initialize()
        
        # 初始化LLM服务
        llm_service = create_llm_service()
        if await llm_service.initialize():
            logger.info("LLM服务初始化完成")
        else:
            logger.warning("LLM服务初始化失败，继续运行")
        
        # 初始化请求管理器
        request_manager = LLMRequestManager(session_manager, llm_service)
        logger.info("请求管理器初始化完成")
        
        # 初始化WebSocket处理器
        websocket_handler = WebSocketHandler()
        websocket_handler.set_services(
            session_manager=session_manager,
            stt_service=stt_service,
            llm_service=llm_service,
            request_manager=request_manager
        )
        
        # 设置请求管理器的WebSocket处理器
        request_manager.set_websocket_handler(websocket_handler)
        
        logger.info("应用启动完成")
        
    except Exception as e:
        logger.error(f"应用启动失败: {e}")
        raise
    
    yield
    
    # 关闭时清理
    logger.info("AI对话应用后端关闭中...")
    
    try:
        # 关闭请求管理器
        if request_manager:
            await request_manager.shutdown()
        
        # 关闭LLM服务
        if llm_service:
            await llm_service.shutdown()
        
        # 关闭STT服务
        if stt_service:
            await stt_service.shutdown()
        
        logger.info("应用关闭完成")
        
    except Exception as e:
        logger.error(f"应用关闭时发生错误: {e}")


# 创建FastAPI应用
app = FastAPI(
    title="AI对话应用后端",
    description="基于FastAPI的实时AI对话应用后端系统",
    version="1.0.0",
    debug=settings.debug,
    lifespan=lifespan
)

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册根健康检查路由（不带前缀）
app.include_router(health_router, tags=["健康检查"])


# WebSocket连接管理已集成到WebSocketHandler中


@app.websocket("/conversation")
async def websocket_endpoint(websocket: WebSocket):
    """
    对话服务WebSocket端点
    
    Args:
        websocket: WebSocket连接
    """
    if websocket_handler:
        # 生成客户端ID
        import uuid
        client_id = f"client_{uuid.uuid4().hex[:8]}"
        await websocket_handler.handle_connection(websocket, client_id)
    else:
        logger.error("WebSocket处理器未初始化")
        await websocket.close()


@app.get("/conversation/health")
async def conversation_health_check():
    """
    对话服务健康检查端点
    
    Returns:
        Dict[str, Any]: 对话服务状态信息
    """
    global session_manager, stt_service, llm_service, request_manager, websocket_handler
    
    # 检查各个服务状态
    services_status = {
        "session_manager": "healthy" if session_manager else "unavailable",
        "stt_service": "healthy" if stt_service else "unavailable",
        "llm_service": "healthy" if llm_service else "unavailable",
        "request_manager": "healthy" if request_manager else "unavailable",
        "websocket_handler": "healthy" if websocket_handler else "unavailable"
    }
    
    # 计算总体状态
    all_healthy = all(status == "healthy" for status in services_status.values())
    overall_status = "healthy" if all_healthy else "degraded"
    
    return {
        "status": overall_status,
        "timestamp": datetime.now().isoformat(),
        "service": "对话服务",
        "version": "1.0.0",
        "services": services_status
    }


if __name__ == "__main__":
    import uvicorn
    import time
    
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level=settings.log_level.lower(),
        ws_ping_interval=settings.websocket_ping_interval,
        ws_ping_timeout=settings.websocket_ping_timeout,
        ws_max_size=settings.websocket_max_message_size,
        timeout_keep_alive=settings.websocket_timeout
    )