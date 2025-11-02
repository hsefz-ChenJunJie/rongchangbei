#!/usr/bin/env python3
"""
意见预测功能测试脚本
测试在用户选择回答后，后端是否能正确触发意见预测并返回结构化的预测结果。
"""

import asyncio
import sys
import os

# 添加项目路径
sys.path.append(os.path.dirname(__file__))
from test_conversation_features import ConversationFeatureTester


class OpinionPredictionTester(ConversationFeatureTester):
    """意见预测功能测试器"""

    async def test_opinion_prediction_flow(self) -> bool:
        """测试用户选择回答后的意见预测流程"""
        print("\n🧪 测试用户选择回答后的意见预测流程...")

        # 1. 确保已有LLM生成的回答可供选择
        if not hasattr(self, 'last_llm_responses') or not self.last_llm_responses:
            print("   - 前置条件：生成一些可供选择的回答...")
            success = await self.send_websocket_event(self.websocket, "manual_generate", {
                "session_id": self.session_id,
            })
            if success:
                llm_event = await self.receive_websocket_event(self.websocket, "llm_response", 30)
                if llm_event:
                    self.last_llm_responses = llm_event["data"].get("suggestions", [])
        
        if not hasattr(self, 'last_llm_responses') or not self.last_llm_responses:
            self.log_test_result("意见预测流程测试", False, "没有可供选择的LLM回答")
            return False

        try:
            # 2. 用户选择一个回答
            selected_response = self.last_llm_responses[0]
            print(f"   - 模拟用户选择回答: '{selected_response[:30]}...'")
            success = await self.send_websocket_event(self.websocket, "user_selected_response", {
                "session_id": self.session_id,
                "selected_content": selected_response,
                "sender": "测试用户"
            })
            if not success:
                self.log_test_result("意见预测流程测试", False, "发送 'user_selected_response' 事件失败")
                return False

            # 3. 等待两个并行的事件：message_recorded 和 opinion_prediction_response
            print("   - 等待 'message_recorded' 和 'opinion_prediction_response' 事件...")
            
            tasks = [
                self.receive_websocket_event(self.websocket, "message_recorded", 10),
                self.receive_websocket_event(self.websocket, "opinion_prediction_response", 30)
            ]

            results = await asyncio.gather(*tasks)
            
            message_recorded_event = None
            opinion_prediction_event = None

            for event in results:
                if event and event.get("type") == "message_recorded":
                    message_recorded_event = event
                elif event and event.get("type") == "opinion_prediction_response":
                    opinion_prediction_event = event

            # 4. 验证事件
            if not message_recorded_event:
                self.log_test_result("意见预测流程测试", False, "未收到 'message_recorded' 事件")
                return False
            print("   - ✅ 已收到 'message_recorded' 事件")

            if not opinion_prediction_event:
                self.log_test_result("意见预测流程测试", False, "未收到 'opinion_prediction_response' 事件")
                return False
            print("   - ✅ 已收到 'opinion_prediction_response' 事件")

            # 5. 验证 opinion_prediction_response 的数据结构
            prediction = opinion_prediction_event.get("data", {}).get("prediction")
            if not prediction or not all(key in prediction for key in ["tendency", "mood", "tone"]):
                self.log_test_result("意见预测流程测试", False, f"'opinion_prediction_response' 数据结构不正确: {prediction}")
                return False
            
            print(f"   - ✅ 预测结果结构正确: {prediction}")
            self.log_test_result("意见预测流程测试", True, "成功接收到结构正确的意见预测")
            return True

        except Exception as e:
            self.log_test_result("意见预测流程测试", False, f"测试异常: {str(e)}")
            return False

    async def run_all_tests(self):
        """重载运行所有测试的方法"""
        print("🚀 开始意见预测功能专项测试...")
        print("=" * 80)
        
        try:
            if not await self.setup_conversation():
                print("❌ 测试环境设置失败，终止测试")
                return False
            
            # 执行核心测试
            await self.test_opinion_prediction_flow()

        finally:
            await self.cleanup_conversation()
        
        summary = self.get_test_summary()
        print(f"\n📊 意见预测功能测试完成")
        print(f"总测试数: {summary['total_tests']}")
        print(f"成功: {summary['passed_tests']}, 失败: {summary['failed_tests']}")
        
        self.save_test_report(f"opinion_prediction_test_report_{self.session_id[:8]}.json")
        return summary['failed_tests'] == 0

def main():
    """主函数"""
    config_file = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    
    tester = OpinionPredictionTester(config_file)
    success = asyncio.run(tester.run_all_tests())
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
