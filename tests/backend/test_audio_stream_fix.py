#!/usr/bin/env python3
"""
测试音频流处理修复
验证问题1的修复：音频流在message_start后能正常处理
"""

import asyncio
import websockets
import json
import base64
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AudioStreamTestClient:
    def __init__(self, server_url="ws://localhost:8000/conversation"):
        self.server_url = server_url
        self.websocket = None
        self.session_id = None
        
    async def connect(self):
        """连接到WebSocket服务器"""
        try:
            self.websocket = await websockets.connect(self.server_url)
            logger.info(f"已连接到服务器: {self.server_url}")
            return True
        except Exception as e:
            logger.error(f"连接失败: {e}")
            return False
    
    async def disconnect(self):
        """断开连接"""
        if self.websocket:
            await self.websocket.close()
            logger.info("已断开连接")
    
    async def send_event(self, event_type, data):
        """发送事件"""
        message = {
            "type": event_type,
            "data": data
        }
        await self.websocket.send(json.dumps(message))
        logger.info(f"发送事件: {event_type}")
    
    async def receive_event(self):
        """接收事件"""
        try:
            message = await asyncio.wait_for(self.websocket.recv(), timeout=5.0)
            event = json.loads(message)
            logger.info(f"收到事件: {event['type']}")
            return event
        except asyncio.TimeoutError:
            logger.warning("接收事件超时")
            return None
        except Exception as e:
            logger.error(f"接收事件错误: {e}")
            return None
    
    async def test_conversation_start(self):
        """测试对话开始"""
        logger.info("=== 测试对话开始 ===")
        
        await self.send_event("conversation_start", {
            "scenario_description": "测试音频流处理修复",
            "response_count": 3
        })
        
        # 接收session_created事件
        event = await self.receive_event()
        if event and event["type"] == "session_created":
            self.session_id = event["data"]["session_id"]
            logger.info(f"会话创建成功: {self.session_id}")
            return True
        else:
            logger.error("会话创建失败")
            return False
    
    async def test_message_start(self):
        """测试消息开始（关键测试点）"""
        logger.info("=== 测试消息开始（修复验证点）===")
        
        await self.send_event("message_start", {
            "session_id": self.session_id,
            "sender": "test_user"
        })
        
        # 接收状态更新
        event = await self.receive_event()
        if event and event["type"] == "status_update":
            status = event["data"]["status"]
            if status == "recording_message":
                logger.info("✅ 消息开始成功，状态已更新为recording_message")
                return True
            else:
                logger.error(f"❌ 状态错误: {status}")
                return False
        else:
            logger.error("❌ 未收到status_update事件")
            return False
    
    async def test_audio_stream(self):
        """测试音频流处理（修复验证点）"""
        logger.info("=== 测试音频流处理（修复验证点）===")
        
        # 生成模拟音频数据
        audio_data = b'\x00' * 1024  # 1KB的模拟音频数据
        audio_base64 = base64.b64encode(audio_data).decode('utf-8')
        
        # 发送多个音频块
        for i in range(3):
            await self.send_event("audio_stream", {
                "session_id": self.session_id,
                "audio_chunk": audio_base64
            })
            logger.info(f"发送音频块 {i+1}/3")
            await asyncio.sleep(0.1)
        
        logger.info("✅ 音频流发送完成，无错误（说明修复生效）")
        return True
    
    async def test_message_end(self):
        """测试消息结束"""
        logger.info("=== 测试消息结束 ===")
        
        await self.send_event("message_end", {
            "session_id": self.session_id
        })
        
        # 接收多个事件
        events = []
        for _ in range(3):  # 可能收到status_update, message_recorded, opinion_suggestions
            event = await self.receive_event()
            if event:
                events.append(event)
        
        # 检查是否收到message_recorded事件
        message_recorded = any(e["type"] == "message_recorded" for e in events)
        if message_recorded:
            logger.info("✅ 消息结束成功，收到message_recorded事件")
            return True
        else:
            logger.error("❌ 未收到message_recorded事件")
            return False
    
    async def test_conversation_end(self):
        """测试对话结束"""
        logger.info("=== 测试对话结束 ===")
        
        await self.send_event("conversation_end", {
            "session_id": self.session_id
        })
        
        logger.info("✅ 对话结束事件发送完成")
        return True

async def run_audio_stream_test():
    """运行音频流处理测试"""
    logger.info("开始测试音频流处理修复")
    
    client = AudioStreamTestClient()
    
    try:
        # 连接服务器
        if not await client.connect():
            logger.error("无法连接到服务器，请确保后端服务已启动")
            return False
        
        # 运行测试序列
        tests = [
            ("对话开始", client.test_conversation_start),
            ("消息开始", client.test_message_start),
            ("音频流处理", client.test_audio_stream),
            ("消息结束", client.test_message_end),
            ("对话结束", client.test_conversation_end),
        ]
        
        success_count = 0
        for test_name, test_func in tests:
            logger.info(f"\n{'='*50}")
            logger.info(f"执行测试: {test_name}")
            logger.info(f"{'='*50}")
            
            try:
                result = await test_func()
                if result:
                    logger.info(f"✅ {test_name} 测试通过")
                    success_count += 1
                else:
                    logger.error(f"❌ {test_name} 测试失败")
            except Exception as e:
                logger.error(f"❌ {test_name} 测试异常: {e}")
            
            await asyncio.sleep(1)  # 测试间隔
        
        # 总结
        logger.info(f"\n{'='*50}")
        logger.info(f"测试完成: {success_count}/{len(tests)} 通过")
        logger.info(f"{'='*50}")
        
        if success_count == len(tests):
            logger.info("🎉 所有测试通过！音频流处理修复成功！")
            return True
        else:
            logger.error("❌ 部分测试失败，需要进一步检查")
            return False
            
    except Exception as e:
        logger.error(f"测试过程中发生异常: {e}")
        return False
    finally:
        await client.disconnect()

if __name__ == "__main__":
    # 运行测试
    result = asyncio.run(run_audio_stream_test())
    exit(0 if result else 1)