"""
健康检查API端点
"""
from fastapi import APIRouter
from typing import Dict, Any
import time
from datetime import datetime

router = APIRouter()


@router.get("/health", response_model=Dict[str, Any])
async def health_check():
    """
    健康检查端点
    
    Returns:
        Dict[str, Any]: 健康状态信息
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "AI对话应用后端",
        "version": "1.0.0"
    }


@router.get("/health/ready", response_model=Dict[str, Any])
async def readiness_check():
    """
    就绪检查端点
    
    Returns:
        Dict[str, Any]: 服务就绪状态
    """
    # TODO: 添加依赖服务检查（STT、LLM等）
    return {
        "status": "ready",
        "timestamp": datetime.utcnow().isoformat(),
        "services": {
            "websocket": "ready",
            "stt": "ready",  # 实际应该检查STT服务状态
            "llm": "ready"   # 实际应该检查LLM服务状态
        }
    }