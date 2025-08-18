#!/usr/bin/env python3
"""
完整对话功能测试脚本
测试远程后端的完整AI对话应用功能，包括STT、LLM、多轮对话等
"""

import asyncio
import sys
import os
from datetime import datetime

# 添加项目路径
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class ConversationFeatureTester(RemoteTestBase):
    """完整对话功能测试器"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        self.websocket = None
        self.session_id = None
        self.message_ids = []
        
    async def setup_conversation(self) -> bool:
        """设置测试对话环境"""
        print("🔧 设置测试环境...")
        
        # 连接WebSocket
        self.websocket = await self.connect_websocket()
        if not self.websocket:
            return False
        
        # 开始对话
        self.session_id = await self.start_conversation(self.websocket)
        if not self.session_id:
            return False
        
        print(f"✅ 测试环境设置完成，会话ID: {self.session_id}")
        return True
    
    async def test_multi_user_conversation(self) -> bool:
        """测试多用户对话"""
        print("\n🧪 测试多用户对话...")
        
        if not self.session_id:
            self.log_test_result("多用户对话测试", False, "会话未初始化")
            return False
        
        try:
            users = self.scenarios["test_users"]
            messages = self.scenarios["test_messages"]
            
            print(f"👥 模拟 {len(users)} 个用户发送消息...")
            
            # 每个用户发送一条消息
            for i, (user, message_text) in enumerate(zip(users, messages)):
                print(f"\n💬 {user}: {message_text}")
                
                # 发送音频消息
                success = await self.send_audio_message(self.websocket, self.session_id, user)
                if not success:
                    self.log_test_result("多用户对话测试", False, f"用户 {user} 消息发送失败")
                    return False
                
                # 等待消息记录确认
                event = await self.receive_websocket_event(self.websocket, "message_recorded", 15)
                if event:
                    message_id = event["data"].get("message_id")
                    self.message_ids.append(message_id)
                    print(f"✅ {user} 的消息已记录，ID: {message_id}")
                    
                    # 等待意见建议（可选）
                    if i == 0:  # 只对第一条消息等待意见建议
                        opinion_event = await self.receive_websocket_event(self.websocket, "opinion_suggestions", 30)
                        if opinion_event:
                            suggestions = opinion_event["data"].get("suggestions", [])
                            print(f"💡 收到意见建议: {suggestions}")
                else:
                    self.log_test_result("多用户对话测试", False, f"用户 {user} 消息记录失败")
                    return False
                
                # 消息间隔
                await asyncio.sleep(1)
            
            self.log_test_result("多用户对话测试", True, f"成功记录 {len(self.message_ids)} 条消息")
            return True
            
        except Exception as e:
            self.log_test_result("多用户对话测试", False, f"测试异常: {str(e)}")
            return False
    
    async def test_focused_message_generation(self) -> bool:
        """测试聚焦消息的回答生成"""
        print("\n🧪 测试聚焦消息生成...")
        
        if len(self.message_ids) < 2:
            self.log_test_result("聚焦消息测试", False, "消息数量不足")
            return False
        
        try:
            # 聚焦前两条消息
            focused_ids = self.message_ids[:2]
            
            success = await self.send_websocket_event(self.websocket, "manual_generate", {
                "session_id": self.session_id,
                "focused_message_ids": focused_ids,
                "user_opinion": "希望针对前面的讨论给出更具体的建议"
            })
            if not success:
                self.log_test_result("聚焦消息测试", False, "聚焦生成请求失败")
                return False
            
            # 等待LLM回答
            llm_event = await self.receive_websocket_event(self.websocket, "llm_response", 30)
            if not llm_event:
                self.log_test_result("聚焦消息测试", False, "未收到LLM回答")
                return False
            
            responses = llm_event["data"].get("suggestions", [])
            
            self.log_test_result(
                "聚焦消息测试", 
                True, 
                f"聚焦消息生成成功，回答数: {len(responses)}，聚焦消息: {focused_ids}"
            )
            return True
            
        except Exception as e:
            self.log_test_result("聚焦消息测试", False, f"测试异常: {str(e)}")
            return False
    
    async def test_user_modification_flow(self) -> bool:
        """测试用户修改建议流程"""
        print("\n🧪 测试用户修改建议...")
        
        try:
            # 发送修改建议
            modification = "请提供更详细的实施步骤，包含时间安排和负责人分配"
            
            success = await self.send_websocket_event(self.websocket, "user_modification", {
                "session_id": self.session_id,
                "modification": modification
            })
            if not success:
                self.log_test_result("用户修改测试", False, "修改建议发送失败")
                return False
            
            print(f"📝 已发送修改建议: {modification}")
            
            # 等待基于修改建议的新回答
            llm_event = await self.receive_websocket_event(self.websocket, "llm_response", 30)
            if not llm_event:
                self.log_test_result("用户修改测试", False, "未收到修改后的回答")
                return False
            
            responses = llm_event["data"].get("suggestions", [])
            
            self.log_test_result(
                "用户修改测试", 
                True, 
                f"修改建议处理成功，新回答数: {len(responses)}"
            )
            
            # 保存一个回答用于后续测试
            if responses:
                self.last_llm_responses = responses
            
            return True
            
        except Exception as e:
            self.log_test_result("用户修改测试", False, f"测试异常: {str(e)}")
            return False
    
    async def test_user_response_selection(self) -> bool:
        """测试用户选择回答"""
        print("\n🧪 测试用户选择回答...")
        
        if not hasattr(self, 'last_llm_responses') or not self.last_llm_responses:
            # 先生成一些回答
            success = await self.send_websocket_event(self.websocket, "manual_generate", {
                "session_id": self.session_id,
                "user_opinion": "生成一些回答供选择"
            })
            if success:
                llm_event = await self.receive_websocket_event(self.websocket, "llm_response", 30)
                if llm_event:
                    self.last_llm_responses = llm_event["data"].get("suggestions", [])
        
        if not hasattr(self, 'last_llm_responses') or not self.last_llm_responses:
            self.log_test_result("用户选择测试", False, "没有可选择的回答")
            return False
        
        try:
            # 选择第一个回答
            selected_response = self.last_llm_responses[0]
            selected_content = selected_response[:100] + "..." if len(selected_response) > 100 else selected_response
            
            success = await self.send_websocket_event(self.websocket, "user_selected_response", {
                "session_id": self.session_id,
                "selected_content": selected_content,
                "sender": "测试用户"
            })
            if not success:
                self.log_test_result("用户选择测试", False, "用户选择发送失败")
                return False
            
            # 等待消息记录确认
            event = await self.receive_websocket_event(self.websocket, "message_recorded", 10)
            if not event:
                self.log_test_result("用户选择测试", False, "用户选择未记录")
                return False
            
            message_id = event["data"].get("message_id")
            self.message_ids.append(message_id)
            
            self.log_test_result(
                "用户选择测试", 
                True, 
                f"用户选择记录成功，消息ID: {message_id}"
            )
            return True
            
        except Exception as e:
            self.log_test_result("用户选择测试", False, f"测试异常: {str(e)}")
            return False
    
    async def test_scenario_supplement(self) -> bool:
        """测试情景补充功能"""
        print("\n🧪 测试情景补充...")
        
        try:
            supplement = "补充信息：这是一个远程团队协作项目，需要考虑时区差异和沟通工具的选择"
            
            success = await self.send_websocket_event(self.websocket, "scenario_supplement", {
                "session_id": self.session_id,
                "supplement": supplement
            })
            if not success:
                self.log_test_result("情景补充测试", False, "情景补充发送失败")
                return False
            
            print(f"📋 已补充情景信息: {supplement}")
            
            # 验证补充后的生成效果
            success = await self.send_websocket_event(self.websocket, "manual_generate", {
                "session_id": self.session_id,
                "user_opinion": "基于补充的情景信息生成建议"
            })
            if success:
                llm_event = await self.receive_websocket_event(self.websocket, "llm_response", 30)
                if llm_event:
                    responses = llm_event["data"].get("suggestions", [])
                    print(f"✅ 基于补充情景生成了 {len(responses)} 个回答")
            
            self.log_test_result("情景补充测试", True, "情景补充功能正常")
            return True
            
        except Exception as e:
            self.log_test_result("情景补充测试", False, f"测试异常: {str(e)}")
            return False
    
    async def test_conversation_persistence(self) -> bool:
        """测试对话持久性（长时间对话）"""
        print("\n🧪 测试对话持久性...")
        
        try:
            # 发送多轮快速交互测试持久性
            interaction_count = 5
            
            for i in range(interaction_count):
                print(f"📞 进行第 {i+1} 轮交互...")
                
                # 发送手动生成请求
                success = await self.send_websocket_event(self.websocket, "manual_generate", {
                    "session_id": self.session_id,
                    "user_opinion": f"第 {i+1} 轮测试交互"
                })
                if not success:
                    self.log_test_result("对话持久性测试", False, f"第 {i+1} 轮交互失败")
                    return False
                
                # 等待回答
                llm_event = await self.receive_websocket_event(self.websocket, "llm_response", 30)
                if not llm_event:
                    self.log_test_result("对话持久性测试", False, f"第 {i+1} 轮未收到回答")
                    return False
                
                # 短暂间隔
                await asyncio.sleep(2)
            
            self.log_test_result("对话持久性测试", True, f"完成 {interaction_count} 轮持续交互")
            return True
            
        except Exception as e:
            self.log_test_result("对话持久性测试", False, f"测试异常: {str(e)}")
            return False
    
    async def cleanup_conversation(self):
        """清理测试环境"""
        print("\n🧹 清理测试环境...")
        
        if self.session_id and self.websocket:
            await self.end_conversation(self.websocket, self.session_id)
        
        if self.websocket:
            await self.websocket.close()
            print("🔌 WebSocket连接已关闭")
    
    async def run_all_tests(self):
        """运行所有对话功能测试"""
        print("🚀 开始完整对话功能测试...")
        print(f"🌐 目标服务器: {self.base_url}")
        print(f"💬 测试场景: {self.scenarios['scenario_description']}")
        print("=" * 80)
        
        try:
            # 1. 设置测试环境
            if not await self.setup_conversation():
                print("❌ 测试环境设置失败，终止测试")
                return False
            
            # 2. 定义测试序列
            tests = [
                self.test_multi_user_conversation(),
                self.test_focused_message_generation(),
                self.test_user_modification_flow(),
                self.test_user_response_selection(),
                self.test_scenario_supplement(),
                self.test_conversation_persistence(),
            ]
            
            # 3. 逐个执行测试
            for test_coro in tests:
                try:
                    await test_coro
                    await asyncio.sleep(1)  # 测试间隔
                except Exception as e:
                    print(f"❌ 测试执行异常: {e}")
                    
        finally:
            await self.cleanup_conversation()
        
        # 生成测试摘要
        summary = self.get_test_summary()
        
        print(f"\n📊 对话功能测试完成")
        print(f"总测试数: {summary['total_tests']}")
        print(f"成功测试: {summary['passed_tests']}")
        print(f"失败测试: {summary['failed_tests']}")
        print(f"成功率: {summary['success_rate']}%")
        print(f"消息记录数: {len(self.message_ids)}")
        
        
        # 保存详细报告
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"conversation_test_report_{timestamp}.json"
        
        # 添加额外的测试数据
        extra_data = {
            "session_id": self.session_id,
            "message_ids": self.message_ids,
            "message_count": len(self.message_ids)
        }
        
        report = {
            "test_config": {
                "server_url": self.base_url,
                "websocket_url": self.ws_url,
                "test_settings": self.test_settings,
                "test_scenario": self.scenarios["scenario_description"]
            },
            "test_summary": summary,
            "test_data": extra_data,
            "event_log": self.event_log,  # 新增：包含事件日志
            "generated_at": datetime.now().isoformat()
        }
        
        try:
            import json
            with open(report_file, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            print(f"📋 详细测试报告已保存: {report_file}")
        except Exception as e:
            print(f"❌ 保存测试报告失败: {e}")
        
        return summary['success_rate'] >= 70  # 对话功能测试容错率稍高


def main():
    """主函数"""
    config_file = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    
    tester = ConversationFeatureTester(config_file)
    result = asyncio.run(tester.run_all_tests())
    
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()