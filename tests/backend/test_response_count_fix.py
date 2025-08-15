#!/usr/bin/env python3
"""
测试response_count_update修复
验证问题2的修复：response_count_update后LLM回答数量能正确变化
"""

import asyncio
import websockets
import json
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ResponseCountTestClient:
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
        logger.info(f"发送事件: {event_type} - {data}")
    
    async def receive_event(self, expected_type=None, timeout=10.0):
        """接收事件"""
        try:
            message = await asyncio.wait_for(self.websocket.recv(), timeout=timeout)
            event = json.loads(message)
            logger.info(f"收到事件: {event['type']} - {event.get('data', {})}")
            
            if expected_type and event["type"] != expected_type:
                logger.warning(f"期望事件类型: {expected_type}, 实际: {event['type']}")
            
            return event
        except asyncio.TimeoutError:
            logger.warning(f"接收事件超时 (等待: {expected_type})")
            return None
        except Exception as e:
            logger.error(f"接收事件错误: {e}")
            return None
    
    async def setup_session_with_message(self):
        """创建会话并添加一条消息"""
        logger.info("=== 设置测试会话 ===")
        
        # 1. 创建会话
        await self.send_event("conversation_start", {
            "scenario_description": "测试response_count修复",
            "response_count": 3  # 初始设置为3
        })
        
        event = await self.receive_event("session_created")
        if not event or event["type"] != "session_created":
            logger.error("会话创建失败")
            return False
        
        self.session_id = event["data"]["session_id"]
        logger.info(f"会话创建成功: {self.session_id}")
        
        # 等待接收opinion_suggestions（如果有历史消息会自动生成）
        await self.receive_event("opinion_suggestions", timeout=3.0)
        
        # 2. 模拟添加一条消息（简化流程，直接添加已选择的回答）
        await self.send_event("user_selected_response", {
            "session_id": self.session_id,
            "selected_content": "这是一条测试消息内容",
            "sender": "test_user"
        })
        
        # 接收message_recorded事件
        event = await self.receive_event("message_recorded")
        if event and event["type"] == "message_recorded":
            logger.info("✅ 测试消息添加成功")
            return True
        else:
            logger.error("❌ 消息添加失败")
            return False
    
    async def test_initial_manual_generate(self):
        """测试初始手动生成（应该返回3个建议）"""
        logger.info("=== 测试初始手动生成（期望3个建议）===")
        
        await self.send_event("manual_generate", {
            "session_id": self.session_id,
            "user_opinion": "测试初始生成"
        })
        
        # 接收status_update
        await self.receive_event("status_update")
        
        # 接收llm_response
        event = await self.receive_event("llm_response")
        if event and event["type"] == "llm_response":
            suggestions = event["data"]["suggestions"]
            count = len(suggestions)
            logger.info(f"收到 {count} 个建议: {suggestions}")
            
            if count == 3:
                logger.info("✅ 初始生成正确，返回3个建议")
                return True
            else:
                logger.error(f"❌ 初始生成错误，期望3个建议，实际{count}个")
                return False
        else:
            logger.error("❌ 未收到llm_response事件")
            return False
    
    async def test_response_count_update(self):
        """测试更新回答数量（修复验证点）"""
        logger.info("=== 测试response_count_update（修复验证点）===")
        
        # 更新为5个回答
        new_count = 5
        await self.send_event("response_count_update", {
            "session_id": self.session_id,
            "response_count": new_count
        })
        
        logger.info(f"✅ 已发送response_count_update，新数量: {new_count}")
        await asyncio.sleep(0.5)  # 给服务器处理时间
        return True
    
    async def test_manual_generate_after_update(self):
        """测试更新后的手动生成（应该返回5个建议）"""
        logger.info("=== 测试更新后手动生成（期望5个建议）===")
        
        await self.send_event("manual_generate", {
            "session_id": self.session_id,
            "user_opinion": "测试更新后生成"
        })
        
        # 接收status_update
        await self.receive_event("status_update")
        
        # 接收llm_response
        event = await self.receive_event("llm_response")
        if event and event["type"] == "llm_response":
            suggestions = event["data"]["suggestions"]
            count = len(suggestions)
            logger.info(f"收到 {count} 个建议: {suggestions}")
            
            if count == 5:
                logger.info("✅ 更新后生成正确，返回5个建议！修复成功！")
                return True
            else:
                logger.error(f"❌ 更新后生成错误，期望5个建议，实际{count}个")
                logger.error("❌ response_count_update修复失败")
                return False
        else:
            logger.error("❌ 未收到llm_response事件")
            return False
    
    async def test_another_count_update(self):
        """测试再次更新回答数量（验证修复的稳定性）"""
        logger.info("=== 测试再次更新数量（验证稳定性）===")
        
        # 更新为2个回答
        new_count = 2
        await self.send_event("response_count_update", {
            "session_id": self.session_id,
            "response_count": new_count
        })
        
        await asyncio.sleep(0.5)
        
        # 再次手动生成
        await self.send_event("manual_generate", {
            "session_id": self.session_id,
            "user_opinion": "测试第二次更新"
        })
        
        # 接收响应
        await self.receive_event("status_update")
        event = await self.receive_event("llm_response")
        
        if event and event["type"] == "llm_response":
            suggestions = event["data"]["suggestions"]
            count = len(suggestions)
            logger.info(f"收到 {count} 个建议: {suggestions}")
            
            if count == 2:
                logger.info("✅ 第二次更新也正确，返回2个建议！修复稳定！")
                return True
            else:
                logger.error(f"❌ 第二次更新错误，期望2个建议，实际{count}个")
                return False
        else:
            logger.error("❌ 未收到llm_response事件")
            return False
    
    async def test_conversation_end(self):
        """清理：结束对话"""
        logger.info("=== 清理：结束对话 ===")
        
        await self.send_event("conversation_end", {
            "session_id": self.session_id
        })
        
        logger.info("✅ 对话结束")
        return True

async def run_response_count_test():
    """运行response_count修复测试"""
    logger.info("开始测试response_count_update修复")
    
    client = ResponseCountTestClient()
    
    try:
        # 连接服务器
        if not await client.connect():
            logger.error("无法连接到服务器，请确保后端服务已启动")
            return False
        
        # 运行测试序列
        tests = [
            ("设置测试会话", client.setup_session_with_message),
            ("初始手动生成(3个)", client.test_initial_manual_generate),
            ("更新回答数量为5", client.test_response_count_update),
            ("更新后手动生成(5个)", client.test_manual_generate_after_update),
            ("再次更新为2个", client.test_another_count_update),
            ("清理会话", client.test_conversation_end),
        ]
        
        success_count = 0
        critical_tests = [1, 3]  # 初始生成和更新后生成是关键测试
        critical_success = 0
        
        for i, (test_name, test_func) in enumerate(tests):
            logger.info(f"\n{'='*60}")
            logger.info(f"执行测试 {i+1}/{len(tests)}: {test_name}")
            logger.info(f"{'='*60}")
            
            try:
                result = await test_func()
                if result:
                    logger.info(f"✅ {test_name} 测试通过")
                    success_count += 1
                    if i in critical_tests:
                        critical_success += 1
                else:
                    logger.error(f"❌ {test_name} 测试失败")
            except Exception as e:
                logger.error(f"❌ {test_name} 测试异常: {e}")
            
            await asyncio.sleep(1)  # 测试间隔
        
        # 总结
        logger.info(f"\n{'='*60}")
        logger.info(f"测试完成: {success_count}/{len(tests)} 通过")
        logger.info(f"关键测试: {critical_success}/{len(critical_tests)} 通过")
        logger.info(f"{'='*60}")
        
        if critical_success == len(critical_tests):
            logger.info("🎉 关键测试全部通过！response_count_update修复成功！")
            return True
        else:
            logger.error("❌ 关键测试失败，response_count_update修复未生效")
            return False
            
    except Exception as e:
        logger.error(f"测试过程中发生异常: {e}")
        return False
    finally:
        await client.disconnect()

if __name__ == "__main__":
    # 运行测试
    result = asyncio.run(run_response_count_test())
    exit(0 if result else 1)