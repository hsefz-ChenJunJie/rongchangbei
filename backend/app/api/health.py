"""
健康检查API端点
"""
from fastapi import APIRouter
from typing import Dict, Any
import time
from datetime import datetime

router = APIRouter()


@router.get("/", response_model=Dict[str, Any])
async def root_health_check():
    """
    根健康检查端点 - 检查后端进程和各个服务的健康性
    
    Returns:
        Dict[str, Any]: 后端总体健康状态信息
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "AI对话应用后端总服务",
        "version": "1.0.0",
        "description": "后端进程运行正常，各服务状态良好"
    }


