#!/usr/bin/env python3
"""
WebSocket功能测试脚本
测试远程后端的WebSocket连接和核心对话功能
"""

import asyncio
import sys
import os
from datetime import datetime

# 添加项目路径
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class WebSocketFeatureTester(RemoteTestBase):
    """WebSocket功能测试器"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        self.websocket = None
        
    async def test_websocket_connection(self) -> bool:
        """测试WebSocket连接"""
        print("\n🧪 测试WebSocket连接...")
        
        self.websocket = await self.connect_websocket()
        success = self.websocket is not None
        
        self.log_test_result(
            "WebSocket连接测试", 
            success,
            "连接成功" if success else "连接失败"
        )
        
        return success
    
    async def test_conversation_flow(self) -> bool:
        """测试完整对话流程"""
        print("\n🧪 测试完整对话流程...")
        
        if not self.websocket:
            self.log_test_result("对话流程测试", False, "WebSocket未连接")
            return False
        
        try:
            # 1. 开始对话
            session_id = await self.start_conversation(self.websocket)
            if not session_id:
                self.log_test_result("对话流程测试", False, "无法开始对话")
                return False
            
            # 2. 发送音频消息
            success = await self.send_audio_message(self.websocket, session_id, "测试用户")
            if not success:
                self.log_test_result("对话流程测试", False, "音频消息发送失败")
                return False
            
            # 等待消息记录确认，可能伴随状态更新
            event = await self.receive_any_websocket_event(self.websocket, ["message_recorded"], 15)
            if not event:
                self.log_test_result("对话流程测试", False, "未收到消息记录确认")
                return False
            
            message_id = event["data"].get("message_id")
            print(f"✅ 消息记录成功，ID: {message_id}")
            
            # 等待意见建议（可选），可能伴随状态更新
            opinion_event = await self.receive_any_websocket_event(self.websocket, ["opinion_suggestions"], 30)
            if opinion_event:
                suggestions = opinion_event["data"].get("suggestions", [])
                print(f"✅ 收到意见建议: {suggestions}")
            else:
                print("✅ 收到意见建议: []")
            
            # 3. 手动生成回答
            success = await self.send_websocket_event(self.websocket, "manual_generate", {
                "session_id": session_id,
                "user_opinion": "希望得到具体的建议"
            })
            if not success:
                self.log_test_result("对话流程测试", False, "手动生成请求失败")
                return False
            
            # 等待LLM回答，可能伴随状态更新
            llm_event = await self.receive_any_websocket_event(self.websocket, ["llm_response"], 30)
            if not llm_event:
                self.log_test_result("对话流程测试", False, "未收到LLM回答")
                return False
            
            responses = llm_event["data"].get("suggestions", [])
            print(f"✅ 收到LLM回答，共 {len(responses)} 个建议")
            
            # 4. 结束对话
            await self.end_conversation(self.websocket, session_id)
            
            self.log_test_result(
                "对话流程测试", 
                True,
                f"完整流程成功，会话ID: {session_id}，LLM回答数: {len(responses)}"
            )
            
            return True
            
        except Exception as e:
            self.log_test_result("对话流程测试", False, f"流程异常: {str(e)}")
            return False
    
    # 注意: 会话恢复/断连测试已移动到独立的 test_disconnect_recovery.py 文件中
    
    async def test_response_count_update(self) -> bool:
        """测试回答数量动态调整"""
        print("\n🧪 测试回答数量动态调整...")
        
        # 为此测试创建新的WebSocket连接
        test_websocket = await self.connect_websocket()
        if not test_websocket:
            self.log_test_result("回答数量测试", False, "无法建立WebSocket连接")
            return False
        
        try:
            # 1. 开始对话
            session_id = await self.start_conversation(test_websocket)
            if not session_id:
                self.log_test_result("回答数量测试", False, "无法开始对话")
                return False
            
            # 2. 修改回答数量为5
            new_count = 5
            success = await self.send_websocket_event(test_websocket, "response_count_update", {
                "session_id": session_id,
                "response_count": new_count
            })
            if not success:
                self.log_test_result("回答数量测试", False, "回答数量更新请求失败")
                return False
            
            # 3. 手动生成验证数量
            success = await self.send_websocket_event(test_websocket, "manual_generate", {
                "session_id": session_id,
                "user_opinion": "测试新的回答数量设置"
            })
            if not success:
                self.log_test_result("回答数量测试", False, "手动生成请求失败")
                return False
            
            # 4. 验证回答数量，可能伴随状态更新
            llm_event = await self.receive_any_websocket_event(test_websocket, ["llm_response"], 30)
            if not llm_event:
                self.log_test_result("回答数量测试", False, "未收到LLM回答")
                return False
            
            responses = llm_event["data"].get("suggestions", [])
            actual_count = len(responses)
            
            if actual_count == new_count:
                self.log_test_result("回答数量测试", True, f"回答数量调整成功: {actual_count}")
                return True
            else:
                self.log_test_result("回答数量测试", False, f"回答数量不匹配，期望: {new_count}，实际: {actual_count}")
                return False
                
        except Exception as e:
            self.log_test_result("回答数量测试", False, f"数量测试异常: {str(e)}")
            return False
        finally:
            # 确保关闭测试连接
            if test_websocket:
                await test_websocket.close()
                print("🔌 回答数量测试连接已关闭")
    
    async def close_websocket(self):
        """关闭WebSocket连接"""
        if self.websocket:
            await self.websocket.close()
            print("🔌 WebSocket连接已关闭")
    
    async def run_all_tests(self):
        """运行所有WebSocket功能测试"""
        print("🚀 开始WebSocket功能测试...")
        print(f"🌐 目标服务器: {self.base_url}")
        print(f"🔌 WebSocket地址: {self.ws_url}")
        print("=" * 60)
        
        try:
            # 定义测试序列（移除断连测试，已独立为test_disconnect_recovery.py）
            tests = [
                self.test_websocket_connection(),
                self.test_conversation_flow(),
                self.test_response_count_update(),
            ]
            
            # 逐个执行测试
            for test_coro in tests:
                try:
                    await test_coro
                    await asyncio.sleep(1)  # 测试间隔
                except Exception as e:
                    print(f"❌ 测试执行异常: {e}")
                    
        finally:
            await self.close_websocket()
        
        # 生成测试摘要
        summary = self.get_test_summary()
        
        print(f"\n📊 测试完成")
        print(f"总测试数: {summary['total_tests']}")
        print(f"成功测试: {summary['passed_tests']}")
        print(f"失败测试: {summary['failed_tests']}")
        print(f"成功率: {summary['success_rate']}%")
        
        
        # 保存报告
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"websocket_test_report_{timestamp}.json"
        self.save_test_report(report_file)
        
        return summary['success_rate'] >= 80


def main():
    """主函数"""
    config_file = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    
    tester = WebSocketFeatureTester(config_file)
    result = asyncio.run(tester.run_all_tests())
    
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()