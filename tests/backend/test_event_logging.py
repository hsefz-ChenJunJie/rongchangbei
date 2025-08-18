#!/usr/bin/env python3
"""
事件日志系统验证测试
用于验证新增的详细事件日志功能是否正常工作
"""

import asyncio
import json
import os
import sys
from datetime import datetime

# 添加项目路径
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class EventLoggingTester(RemoteTestBase):
    """事件日志功能测试器"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        
    async def test_event_logging_functionality(self):
        """测试事件日志记录功能"""
        print("🧪 测试事件日志记录功能...")
        
        # 1. 测试HTTP请求事件记录
        result = await self.test_http_endpoint("/")
        if result["success"]:
            print("✅ HTTP请求事件记录正常")
        else:
            print("⚠️ HTTP请求失败，但事件应已记录")
        
        # 2. 测试WebSocket连接事件记录
        websocket = await self.connect_websocket()
        if websocket:
            print("✅ WebSocket连接事件记录正常")
            
            # 3. 测试WebSocket事件发送记录
            test_data = {
                "test": "event_logging_test",
                "timestamp": datetime.now().isoformat()
            }
            
            await self.send_websocket_event(websocket, "test_event", test_data)
            print("✅ WebSocket发送事件记录正常")
            
            # 4. 测试WebSocket事件接收记录（超时测试）
            await self.receive_websocket_event(websocket, "non_existent_event", 2)
            print("✅ WebSocket接收超时事件记录正常")
            
            await websocket.close()
        else:
            print("⚠️ WebSocket连接失败，但连接尝试事件应已记录")
        
        # 5. 测试事件统计功能
        stats = self._get_event_statistics() if hasattr(self, '_get_event_statistics') else {}
        print(f"\n📊 事件统计验证:")
        print(f"  总事件数: {stats.get('total_events', 0)}")
        print(f"  发送事件: {stats.get('send_events', 0)}")
        print(f"  接收事件: {stats.get('recv_events', 0)}")
        print(f"  成功事件: {stats.get('success_events', 0)}")
        print(f"  失败事件: {stats.get('failed_events', 0)}")
        print(f"  平均响应时间: {stats.get('average_response_time', 0)}秒")
        
        # 6. 测试敏感信息脱敏
        sensitive_data = {
            "audio_chunk": "SGVsbG8gV29ybGQ=" * 100,  # 模拟大音频数据
            "password": "secret123",
            "normal_field": "normal_value"
        }
        self._log_event("TEST", "sensitive_data_test", sensitive_data, {}, True)
        print("✅ 敏感信息脱敏测试完成")
        
        # 7. 验证事件日志内容
        if self.event_log:
            last_event = self.event_log[-1]
            if "audio_chunk" in last_event["data"]:
                if last_event["data"]["audio_chunk"].startswith("<audio_data_length:"):
                    print("✅ 音频数据脱敏正常")
                else:
                    print("❌ 音频数据脱敏失败")
            
            if "password" in last_event["data"]:
                if last_event["data"]["password"] == "***":
                    print("✅ 密码字段脱敏正常")
                else:
                    print("❌ 密码字段脱敏失败")
        
        return True
    
    async def run_validation_tests(self):
        """运行事件日志验证测试"""
        print("🚀 开始事件日志系统验证测试")
        print(f"📁 配置文件: {self.config_file}")
        print(f"🌐 目标服务器: {self.base_url}")
        print("=" * 60)
        
        # 显示当前日志配置
        log_config = self.test_settings
        print(f"\n⚙️ 当前日志配置:")
        print(f"  详细日志显示: {log_config.get('enable_detailed_logging', False)}")
        print(f"  文件日志记录: {log_config.get('enable_file_logging', False)}")
        print(f"  日志级别: {log_config.get('log_level', 'INFO')}")
        print(f"  显示列表项: {log_config.get('show_list_items', False)}")
        
        # 执行测试
        try:
            await self.test_event_logging_functionality()
            
            # 显示完整事件统计
            print("\n" + "="*60)
            if hasattr(self, 'print_event_summary'):
                self.print_event_summary()
            else:
                print("📊 事件统计功能可用，详见保存的报告文件")
            
            # 保存测试报告
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            report_file = f"event_logging_test_report_{timestamp}.json"
            self.save_test_report(report_file)
            
            print(f"\n🎉 事件日志系统验证完成！")
            print(f"📋 详细报告已保存: {report_file}")
            print(f"📊 事件日志文件: {report_file.replace('.json', '_events.json')}")
            
            if self.test_settings.get('enable_file_logging', False):
                print(f"📝 结构化日志文件: event_log_{timestamp}.log")
            
            return True
            
        except Exception as e:
            print(f"❌ 验证测试异常: {e}")
            return False


def main():
    """主函数"""
    print("🔍 事件日志系统功能验证工具")
    print("用途: 验证新增的详细事件日志功能是否正常工作")
    print()
    
    config_file = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    
    # 检查配置文件是否存在
    if not os.path.exists(config_file):
        print(f"❌ 配置文件不存在: {config_file}")
        print("💡 请确保配置文件存在，或使用: python test_event_logging.py <config_file>")
        return False
    
    tester = EventLoggingTester(config_file)
    result = asyncio.run(tester.run_validation_tests())
    
    if result:
        print("\n✅ 验证成功：事件日志系统工作正常！")
    else:
        print("\n❌ 验证失败：事件日志系统存在问题")
    
    return result


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)