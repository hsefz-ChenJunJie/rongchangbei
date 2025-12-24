#!/usr/bin/env python3
"""
用户/对话对象档案回传测试（mock）
验证：
1) conversation_start 支持携带用户档案和对话对象档案
2) conversation_end 后后端返回 profile_archive 事件，包含存储的档案
"""

import asyncio
import sys
import os
from typing import Dict, Any

# 添加项目路径，复用远程测试基础类
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class ProfileArchiveTester(RemoteTestBase):
    """档案回传专项测试"""

    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        self.websocket = None
        self.session_id = None
        self.user_profile: Dict[str, Any] = {}
        self.target_profile: Dict[str, Any] = {}

    async def setup_test(self) -> bool:
        """建立连接并创建会话，携带档案"""
        print("🔧 正在准备档案测试环境...")
        self.websocket = await self.connect_websocket()
        if not self.websocket:
            return False

        self.user_profile = {
            "name": "测试用户",
            "age": 28,
            "gender": "female",
            "relations": ["self"],
            "personalities": ["专注", "理性"],
            "preferences": ["简洁表达", "行动项优先"],
            "taboos": ["含糊其辞"],
            "common_topics": ["项目进展", "技术分享"],
        }
        self.target_profile = {
            "name": "对话机器人",
            "age": 2,
            "gender": "neutral",
            "relations": ["assistant"],
            "personalities": ["友好", "耐心"],
            "preferences": ["明确问题", "逐步澄清"],
            "taboos": ["过度承诺"],
            "common_topics": ["任务拆解", "需求澄清"],
        }

        self.session_id = await self.start_conversation(
            self.websocket,
            user_profile=self.user_profile,
            target_profile=self.target_profile,
        )
        return bool(self.session_id)

    async def cleanup_test(self):
        """结束会话并关闭连接"""
        try:
            if self.websocket and self.session_id:
                await self.end_conversation(self.websocket, self.session_id)
        finally:
            if self.websocket:
                await self.websocket.close()

    async def test_profile_archive_roundtrip(self) -> bool:
        """验证档案在 conversation_end 后能回传"""
        print("\n🧪 测试 profile_archive 回传...")
        if not self.session_id:
            self.log_test_result("档案回传", False, "会话未初始化")
            return False

        # 触发对话结束
        await self.send_websocket_event(self.websocket, "conversation_end", {"session_id": self.session_id})

        # 等待 profile_archive 事件
        event = await self.receive_any_websocket_event(
            self.websocket,
            ["profile_archive"],
            timeout=self.test_settings.get("response_timeout", 30),
            max_attempts=3,
        )
        if not event:
            self.log_test_result("档案回传", False, "未收到 profile_archive 事件")
            return False

        data = event.get("data", {})
        user_profile = data.get("user_profile") or {}
        target_profile = data.get("target_profile") or {}

        def _cmp(expected: Dict[str, Any], actual: Dict[str, Any]) -> bool:
            return all(str(expected.get(k)) == str(actual.get(k)) for k in expected.keys())

        if _cmp(self.user_profile, user_profile) and _cmp(self.target_profile, target_profile):
            self.log_test_result("档案回传", True, "档案回传与输入一致")
            return True

        self.log_test_result(
            "档案回传",
            False,
            "档案回传内容与输入不一致",
            data={"expected_user": self.user_profile, "actual_user": user_profile},
        )
        return False

    async def run_all_tests(self):
        """运行档案相关测试"""
        print("🚀 开始档案回传专项测试...")
        print("=" * 80)

        if not await self.setup_test():
            print("❌ 档案测试环境准备失败")
            return False

        try:
            await self.test_profile_archive_roundtrip()
        finally:
            await self.cleanup_test()

        summary = self.get_test_summary()
        print(f"\n📊 测试完成，总数 {summary['total_tests']}，成功 {summary['passed_tests']}，失败 {summary['failed_tests']}")

        report_name = f"profile_archive_report_{self.session_id[:8]}.json" if self.session_id else None
        self.save_test_report(report_name)
        return summary["failed_tests"] == 0


def main():
    """主函数"""
    config_file = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    tester = ProfileArchiveTester(config_file)
    success = asyncio.run(tester.run_all_tests())
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
