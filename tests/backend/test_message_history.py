#!/usr/bin/env python3
"""
消息历史功能测试

测试get_message_history事件的完整功能，包括：
1. 历史消息（对话开始时传入）
2. 录制消息（音频转录）  
3. 用户选择的回答（选择LLM建议）

测试遵循tests/backend规范，基于RemoteTestBase框架
"""

import asyncio
import json
import websockets
import uuid
from datetime import datetime
from remote_test_base import RemoteTestBase


class MessageHistoryTest(RemoteTestBase):
    """消息历史功能测试类"""
    
    def __init__(self):
        super().__init__()
        self.test_name = "消息历史功能测试"
        print(f"\n🧪 {self.test_name}")
        print("=" * 50)
    
    async def run_tests(self):
        """运行所有消息历史测试"""
        tests = [
            ("基础连接测试", self.test_basic_connection),
            ("完整消息历史测试", self.test_complete_message_history),
            ("空会话消息历史测试", self.test_empty_session_history),
            ("不存在会话测试", self.test_nonexistent_session),
        ]
        
        total_tests = len(tests)
        passed_tests = 0
        
        for test_name, test_func in tests:
            print(f"\n🔍 运行测试: {test_name}")
            try:
                success = await test_func()
                if success:
                    print(f"✅ {test_name} - 通过")
                    passed_tests += 1
                else:
                    print(f"❌ {test_name} - 失败")
            except Exception as e:
                print(f"💥 {test_name} - 异常: {e}")
                self.test_results.append({
                    "test_name": test_name,
                    "success": False,
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                })
        
        # 打印测试总结
        success_rate = (passed_tests / total_tests) * 100
        print(f"\n📊 测试总结:")
        print(f"   总测试数: {total_tests}")
        print(f"   通过数量: {passed_tests}")
        print(f"   成功率: {success_rate:.1f}%")
        
        # 保存测试报告
        await self.save_test_report()
        
        return success_rate >= 70  # 70%通过率视为成功
    
    async def test_basic_connection(self):
        """测试基础连接功能"""
        try:
            # HTTP健康检查
            success = await self.test_http_endpoint("/", "GET")
            if not success:
                return False
            
            # WebSocket连接测试
            websocket = await self.connect_websocket()
            if not websocket:
                return False
            
            await websocket.close()
            return True
            
        except Exception as e:
            print(f"基础连接测试失败: {e}")
            return False
    
    async def test_complete_message_history(self):
        """测试完整的消息历史功能"""
        websocket = await self.connect_websocket()
        if not websocket:
            return False
        
        try:
            # 1. 创建带历史消息的对话
            history_messages = [
                {
                    "message_id": "hist_001",
                    "sender": "张三",
                    "content": "我们来讨论一下项目计划"
                },
                {
                    "message_id": "hist_002",
                    "sender": "李四",
                    "content": "好的，先确定时间节点"
                }
            ]
            
            start_event = {
                "type": "conversation_start",
                "data": {
                    "scenario_description": "项目管理讨论",
                    "response_count": 3,
                    "history_messages": history_messages
                }
            }
            
            await self.send_websocket_event(websocket, start_event)
            
            # 等待session_created事件
            session_created = await self.receive_websocket_event(websocket, "session_created")
            if not session_created:
                print("未收到session_created事件")
                return False
            
            session_id = session_created["data"]["session_id"]
            self.session_id = session_id
            print(f"📝 会话已创建: {session_id}")
            
            # 2. 发送录制消息
            await self._send_audio_message(websocket, session_id, "王五", "我负责前端开发部分")
            
            # 3. 触发LLM回答生成
            manual_generate_event = {
                "type": "manual_generate",
                "data": {
                    "session_id": session_id,
                    "user_opinion": "需要具体的时间安排"
                }
            }
            
            await self.send_websocket_event(websocket, manual_generate_event)
            
            # 等待LLM回答
            llm_response = await self.receive_websocket_event(websocket, "llm_response")
            if not llm_response:
                print("未收到llm_response事件")
                return False
            
            # 4. 用户选择回答
            selected_response = llm_response["data"]["suggestions"][0]
            select_event = {
                "type": "user_selected_response",
                "data": {
                    "session_id": session_id,
                    "selected_content": selected_response,
                    "sender": "系统"
                }
            }
            
            await self.send_websocket_event(websocket, select_event)
            
            # 等待消息记录确认
            message_recorded = await self.receive_websocket_event(websocket, "message_recorded")
            if not message_recorded:
                print("未收到用户选择的message_recorded事件")
                return False
            
            # 5. 测试get_message_history事件
            history_event = {
                "type": "get_message_history",
                "data": {
                    "session_id": session_id
                }
            }
            
            await self.send_websocket_event(websocket, history_event)
            
            # 等待消息历史响应
            history_response = await self.receive_websocket_event(websocket, "message_history_response")
            if not history_response:
                print("未收到message_history_response事件")
                return False
            
            # 6. 验证消息历史内容
            messages = history_response["data"]["messages"]
            total_count = history_response["data"]["total_count"]
            
            print(f"📜 收到消息历史，总数: {total_count}")
            
            # 验证消息类型和内容
            expected_types = ["history", "history", "recording", "selected_response"]
            if total_count != len(expected_types):
                print(f"消息数量不匹配，期望: {len(expected_types)}, 实际: {total_count}")
                return False
            
            for i, message in enumerate(messages):
                expected_type = expected_types[i]
                actual_type = message["message_type"]
                
                if actual_type != expected_type:
                    print(f"消息类型不匹配 [{i}]，期望: {expected_type}, 实际: {actual_type}")
                    return False
                
                print(f"  {i+1}. [{actual_type}] {message['sender']}: {message['content'][:50]}...")
            
            print("✅ 消息历史内容验证通过")
            
            return True
            
        except Exception as e:
            print(f"完整消息历史测试失败: {e}")
            return False
        finally:
            if websocket:
                await websocket.close()
    
    async def test_empty_session_history(self):
        """测试空会话的消息历史"""
        websocket = await self.connect_websocket()
        if not websocket:
            return False
        
        try:
            # 创建无历史消息的对话
            start_event = {
                "type": "conversation_start",
                "data": {
                    "scenario_description": "空白对话",
                    "response_count": 2
                }
            }
            
            await self.send_websocket_event(websocket, start_event)
            
            # 等待session_created事件
            session_created = await self.receive_websocket_event(websocket, "session_created")
            if not session_created:
                return False
            
            session_id = session_created["data"]["session_id"]
            
            # 直接测试get_message_history
            history_event = {
                "type": "get_message_history",
                "data": {
                    "session_id": session_id
                }
            }
            
            await self.send_websocket_event(websocket, history_event)
            
            # 等待响应
            history_response = await self.receive_websocket_event(websocket, "message_history_response")
            if not history_response:
                return False
            
            total_count = history_response["data"]["total_count"]
            if total_count != 0:
                print(f"空会话应该没有消息，但收到: {total_count}")
                return False
            
            print("✅ 空会话消息历史测试通过")
            return True
            
        except Exception as e:
            print(f"空会话消息历史测试失败: {e}")
            return False
        finally:
            if websocket:
                await websocket.close()
    
    async def test_nonexistent_session(self):
        """测试不存在的会话"""
        websocket = await self.connect_websocket()
        if not websocket:
            return False
        
        try:
            # 使用不存在的session_id
            fake_session_id = "fake_session_" + str(uuid.uuid4())
            
            history_event = {
                "type": "get_message_history",
                "data": {
                    "session_id": fake_session_id
                }
            }
            
            await self.send_websocket_event(websocket, history_event)
            
            # 应该收到错误事件
            error_response = await self.receive_websocket_event(websocket, "error")
            if not error_response:
                print("未收到期望的错误事件")
                return False
            
            error_code = error_response["data"]["error_code"]
            if error_code != "SESSION_NOT_FOUND":
                print(f"错误代码不正确，期望: SESSION_NOT_FOUND, 实际: {error_code}")
                return False
            
            print("✅ 不存在会话错误处理测试通过")
            return True
            
        except Exception as e:
            print(f"不存在会话测试失败: {e}")
            return False
        finally:
            if websocket:
                await websocket.close()
    
    async def _send_audio_message(self, websocket, session_id, sender, expected_content):
        """发送音频消息的辅助方法"""
        # 发送消息开始
        message_start = {
            "type": "message_start",
            "data": {
                "session_id": session_id,
                "sender": sender
            }
        }
        await self.send_websocket_event(websocket, message_start)
        
        # 发送音频流（模拟）
        audio_chunk = base64.b64encode(b"fake_audio_data").decode()
        audio_stream = {
            "type": "audio_stream",
            "data": {
                "session_id": session_id,
                "audio_chunk": audio_chunk
            }
        }
        await self.send_websocket_event(websocket, audio_stream)
        
        # 发送消息结束
        message_end = {
            "type": "message_end",
            "data": {
                "session_id": session_id
            }
        }
        await self.send_websocket_event(websocket, message_end)
        
        # 等待消息记录确认
        message_recorded = await self.receive_websocket_event(websocket, "message_recorded")
        if message_recorded:
            print(f"📝 录制消息已确认: {message_recorded['data']['message_id']}")
            return True
        
        return False
    
    async def receive_any_websocket_event(self, websocket, expected_types, timeout=10):
        """接收任意指定类型的WebSocket事件，自动跳过status_update"""
        if isinstance(expected_types, str):
            expected_types = [expected_types]
            
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=2)
                event = json.loads(message)
                event_type = event.get("type")
                
                # 跳过状态更新事件
                if event_type == "status_update":
                    continue
                
                # 检查是否是期望的事件类型
                if event_type in expected_types:
                    return event
                else:
                    print(f"🔄 跳过非期望事件: {event_type}")
                    
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                print(f"接收事件时出错: {e}")
                break
        
        print(f"⏰ 超时未收到期望事件: {expected_types}")
        return None
    
    async def save_test_report(self):
        """保存测试报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"message_history_test_report_{timestamp}.json"
        
        report = {
            "test_name": self.test_name,
            "timestamp": datetime.now().isoformat(),
            "configuration": {
                "target_server": self.base_url,
                "websocket_url": self.ws_url
            },
            "test_results": self.test_results,
            "event_log": self.event_log,
            "summary": {
                "total_tests": len(self.test_results),
                "passed_tests": len([r for r in self.test_results if r.get("success", False)]),
                "failed_tests": len([r for r in self.test_results if not r.get("success", False)])
            }
        }
        
        try:
            with open(report_file, "w", encoding="utf-8") as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            print(f"📄 测试报告已保存: {report_file}")
        except Exception as e:
            print(f"保存测试报告失败: {e}")


async def main():
    """主函数"""
    test = MessageHistoryTest()
    
    # 检查服务器连通性
    print("🔍 检查服务器连通性...")
    if not await test.test_http_endpoint("/", "GET"):
        print("❌ 服务器不可达，请检查后端服务是否运行")
        return False
    
    print("✅ 服务器连通性正常")
    
    # 运行测试
    success = await test.run_tests()
    
    if success:
        print(f"\n🎉 {test.test_name}完成！")
        return True
    else:
        print(f"\n💔 {test.test_name}存在问题，请检查报告")
        return False


if __name__ == "__main__":
    import sys
    success = asyncio.run(main())
    sys.exit(0 if success else 1)