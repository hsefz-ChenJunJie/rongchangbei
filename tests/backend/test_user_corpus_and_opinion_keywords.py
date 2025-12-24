#!/usr/bin/env python3
"""
用户语料与意见关键词功能测试
验证 manual_generate 对 user_corpus 的支持，以及自动意见关键词预测事件。
"""

import asyncio
import sys
import os
import time

# 添加项目路径，复用远程测试基础类
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class UserCorpusAndOpinionKeywordTester(RemoteTestBase):
    """用户语料与意见关键词专项测试"""

    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        self.websocket = None
        self.session_id = None
        self.last_message_id = None
        self.last_llm_responses = []

    async def setup_test(self) -> bool:
        """建立连接并创建会话"""
        print("🔧 正在准备测试环境...")
        self.websocket = await self.connect_websocket()
        if not self.websocket:
            return False

        self.session_id = await self.start_conversation(self.websocket)
        return bool(self.session_id)

    async def cleanup_test(self):
        """结束会话并关闭连接"""
        try:
            if self.websocket and self.session_id:
                await self.end_conversation(self.websocket, self.session_id)
        finally:
            if self.websocket:
                await self.websocket.close()

    async def record_single_message(self, sender: str) -> str:
        """发送一条音频消息并等待 message_recorded"""
        success = await self.send_audio_message(self.websocket, self.session_id, sender)
        if not success:
            return ""

        event = await self.receive_any_websocket_event(
            self.websocket,
            ["message_recorded"],
            timeout=self.test_settings.get("response_timeout", 30),
            max_attempts=3,
        )
        if not event:
            return ""

        message_id = event["data"].get("message_id")
        self.last_message_id = message_id
        return message_id or ""

    async def test_manual_generate_with_user_corpus(self) -> bool:
        """验证 manual_generate 能携带用户语料并返回回答"""
        print("\n🧪 测试 user_corpus 接口...")

        message_id = await self.record_single_message("语料测试用户")
        if not message_id:
            self.log_test_result("user_corpus 接口", False, "未获得 message_recorded 事件")
            return False

        user_corpus = "用户提供的背景语料：请回复时引用项目里程碑和风险提示。"
        user_background = "身份：产品负责人，需要向管理层汇报"
        user_preferences = "偏好：要点式回答、结论先行、数据支撑"
        user_recent_experiences = "近期经历：刚完成一次重要的版本发布，对稳定性和风险敏感"
        payload = {
            "session_id": self.session_id,
            "focused_message_ids": [message_id],
            "user_corpus": user_corpus,
            "user_background": user_background,
            "user_preferences": user_preferences,
            "user_recent_experiences": user_recent_experiences,
        }

        if not await self.send_websocket_event(self.websocket, "manual_generate", payload):
            self.log_test_result("user_corpus 接口", False, "发送 manual_generate 失败")
            return False

        llm_event = await self.receive_any_websocket_event(
            self.websocket,
            ["llm_response"],
            timeout=self.test_settings.get("response_timeout", 30),
            max_attempts=3,
        )
        if not llm_event:
            self.log_test_result("user_corpus 接口", False, "未收到 llm_response 事件")
            return False

        suggestions = llm_event.get("data", {}).get("suggestions", [])
        self.last_llm_responses = suggestions or []
        if suggestions and all(isinstance(s, str) for s in suggestions):
            detail = f"收到 {len(suggestions)} 条回答，已携带 user_corpus 触发生成"
            self.log_test_result("user_corpus 接口", True, detail)
            return True

        self.log_test_result(
            "user_corpus 接口",
            False,
            f"llm_response 数据异常: {llm_event.get('data')}",
        )
        return False

    async def test_opinion_keyword_prediction(self) -> bool:
        """验证用户选择回答后触发的 opinion_prediction_response"""
        print("\n🧪 测试意见预测（用户选择回答后触发）...")

        # 如果还没有LLM建议，先手动生成一组
        if not self.last_llm_responses:
            if not await self.test_manual_generate_with_user_corpus():
                self.log_test_result("意见预测", False, "获取LLM建议失败，无法继续")
                return False

        if not self.last_llm_responses:
            self.log_test_result("意见预测", False, "无可选LLM回答，无法触发预测")
            return False

        selected_response = self.last_llm_responses[0]
        print(f"   - 模拟用户选择回答: '{selected_response[:40]}...'")
        send_ok = await self.send_websocket_event(self.websocket, "user_selected_response", {
            "session_id": self.session_id,
            "selected_content": selected_response,
            "sender": "意见预测测试用户"
        })
        if not send_ok:
            self.log_test_result("意见预测", False, "发送 user_selected_response 失败")
            return False

        # 依次等待 message_recorded 和 opinion_prediction_response（避免并发 recv 冲突）
        needed = {"message_recorded": None, "opinion_prediction_response": None}
        deadline = time.time() + self.test_settings.get("opinion_timeout", 40)
        while time.time() < deadline and (not needed["message_recorded"] or not needed["opinion_prediction_response"]):
            remaining = max(0.5, deadline - time.time())
            event = await self.receive_any_websocket_event(
                self.websocket,
                ["message_recorded", "opinion_prediction_response", "status_update"],
                timeout=min(remaining, self.test_settings.get("response_timeout", 30)),
                max_attempts=1,
            )
            if not event:
                continue
            event_type = event.get("type")
            if event_type == "status_update":
                continue
            if event_type in needed and needed[event_type] is None:
                needed[event_type] = event

        msg_event = needed["message_recorded"]
        opinion_event = needed["opinion_prediction_response"]

        if not msg_event:
            self.log_test_result("意见预测", False, "未收到 message_recorded 事件")
            return False

        if not opinion_event:
            self.log_test_result("意见预测", False, "未收到 opinion_prediction_response 事件")
            return False

        prediction = opinion_event.get("data", {}).get("prediction")
        required_keys = {"tendency", "mood", "tone"}
        if isinstance(prediction, dict) and required_keys.issubset(prediction.keys()):
            detail = f"预测结果: {prediction}"
            self.log_test_result("意见预测", True, detail)
            return True

        self.log_test_result(
            "意见预测",
            False,
            f"opinion_prediction_response 数据结构不正确: {prediction}",
        )
        return False

    async def run_all_tests(self):
        """运行所有相关测试"""
        print("🚀 开始用户语料与意见关键词专项测试...")
        print("=" * 80)

        if not await self.setup_test():
            print("❌ 测试环境准备失败")
            return False

        try:
            await self.test_manual_generate_with_user_corpus()
            await self.test_opinion_keyword_prediction()
        finally:
            await self.cleanup_test()

        summary = self.get_test_summary()
        print(f"\n📊 测试完成，总数 {summary['total_tests']}，成功 {summary['passed_tests']}，失败 {summary['failed_tests']}")

        report_name = f"user_corpus_and_opinion_keywords_report_{self.session_id[:8]}.json" if self.session_id else None
        self.save_test_report(report_name)
        return summary["failed_tests"] == 0


def main():
    """主函数"""
    config_file = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    tester = UserCorpusAndOpinionKeywordTester(config_file)
    success = asyncio.run(tester.run_all_tests())
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
