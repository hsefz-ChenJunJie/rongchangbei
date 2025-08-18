#!/usr/bin/env python3
"""
WebSocket断连恢复测试脚本
测试各种断连场景下的会话恢复功能
"""

import asyncio
import sys
import os
from datetime import datetime
from typing import Dict, List, Any

# 添加项目路径
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class DisconnectRecoveryTester(RemoteTestBase):
    """断连恢复测试器"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        
        # 从配置文件加载断连测试设置
        self.disconnect_config = self.config.get("disconnect_test", {})
        
        # 断连测试配置
        self.enable_disconnect_test = self.disconnect_config.get("enable_disconnect_test", True)
        self.disconnect_scenarios = self.disconnect_config.get("disconnect_scenarios", [])
        self.test_rounds = self.disconnect_config.get("test_rounds", 2)
        self.round_interval = self.disconnect_config.get("round_interval", 3)
        self.reconnection_timeout = self.disconnect_config.get("reconnection_timeout", 15)
        self.recovery_timeout = self.disconnect_config.get("recovery_timeout", 10)
        
        # 默认断连场景（如果配置为空）
        if not self.disconnect_scenarios:
            self.disconnect_scenarios = [
                {
                    "name": "短暂断连",
                    "disconnect_duration": 3,
                    "expected_result": "session_restored"
                }
            ]
    
    async def test_single_disconnect_scenario(self, scenario: Dict[str, Any]) -> bool:
        """测试单个断连场景"""
        scenario_name = scenario.get("name", "未命名场景")
        disconnect_duration = scenario.get("disconnect_duration", 5)
        expected_result = scenario.get("expected_result", "session_restored")
        
        print(f"\n🧪 测试断连场景: {scenario_name}")
        print(f"   断连时长: {disconnect_duration} 秒")
        print(f"   预期结果: {expected_result}")
        
        websocket = None
        session_id = None
        
        try:
            # 1. 建立连接并创建会话
            print("🔌 建立WebSocket连接...")
            websocket = await self.connect_websocket()
            if not websocket:
                self.log_test_result(f"断连测试-{scenario_name}", False, "无法建立WebSocket连接")
                return False
            
            # 2. 开始对话并创建会话
            print("🆕 创建测试会话...")
            session_id = await self.start_conversation(
                websocket,
                scenario_description=f"断连恢复测试-{scenario_name}",
                response_count=2
            )
            if not session_id:
                self.log_test_result(f"断连测试-{scenario_name}", False, "无法创建会话")
                return False
            
            print(f"✅ 会话创建成功: {session_id}")
            
            # 3. 发送一条测试消息以建立会话状态
            print("📝 发送测试消息...")
            success = await self.send_audio_message(websocket, session_id, "断连测试用户")
            if not success:
                print("⚠️ 测试消息发送失败，但继续测试")
            
            # 等待消息处理
            await asyncio.sleep(1)
            
            # 4. 模拟断连
            print(f"🔌 模拟连接断开（{disconnect_duration}秒）...")
            await websocket.close()
            websocket = None
            
            # 5. 等待指定的断连时长
            print(f"⏳ 等待 {disconnect_duration} 秒...")
            await asyncio.sleep(disconnect_duration)
            
            # 6. 尝试重新连接
            print("🔄 尝试重新连接...")
            websocket = await self.connect_websocket()
            if not websocket:
                self.log_test_result(f"断连测试-{scenario_name}", False, "重连失败")
                return False
            
            print("✅ 重连成功")
            
            # 7. 尝试恢复会话
            print(f"🔄 尝试恢复会话: {session_id}")
            success = await self.send_websocket_event(websocket, "session_resume", {
                "session_id": session_id
            })
            if not success:
                self.log_test_result(f"断连测试-{scenario_name}", False, "恢复请求发送失败")
                return False
            
            # 8. 等待恢复结果
            print(f"⏳ 等待恢复结果（超时: {self.recovery_timeout}秒）...")
            
            if expected_result == "session_restored":
                # 期望恢复成功
                restore_event = await self.receive_websocket_event(websocket, "session_restored", self.recovery_timeout)
                if restore_event:
                    restored_data = restore_event["data"]
                    message_count = restored_data.get("message_count", 0)
                    print(f"✅ 会话恢复成功!")
                    print(f"   恢复的消息数: {message_count}")
                    print(f"   会话状态: {restored_data.get('status', 'unknown')}")
                    
                    self.log_test_result(f"断连测试-{scenario_name}", True, 
                        f"会话恢复成功，消息数: {message_count}")
                    return True
                else:
                    # 检查是否收到错误信息
                    error_event = await self.receive_websocket_event(websocket, "error", 5)
                    if error_event:
                        error_code = error_event["data"].get("error_code")
                        error_message = error_event["data"].get("message", "未知错误")
                        print(f"❌ 收到错误: {error_code} - {error_message}")
                        self.log_test_result(f"断连测试-{scenario_name}", False, 
                            f"预期恢复成功但收到错误: {error_code}")
                    else:
                        print("❌ 超时，未收到恢复确认")
                        self.log_test_result(f"断连测试-{scenario_name}", False, "恢复超时")
                    return False
            
            elif expected_result == "session_not_found":
                # 期望恢复失败（会话过期）
                error_event = await self.receive_websocket_event(websocket, "error", self.recovery_timeout)
                if error_event:
                    error_code = error_event["data"].get("error_code")
                    if error_code == "SESSION_NOT_FOUND":
                        print("✅ 会话已过期（符合预期）")
                        self.log_test_result(f"断连测试-{scenario_name}", True, 
                            "会话过期处理正确")
                        return True
                    else:
                        print(f"❌ 收到非预期错误: {error_code}")
                        self.log_test_result(f"断连测试-{scenario_name}", False, 
                            f"预期SESSION_NOT_FOUND但收到: {error_code}")
                        return False
                else:
                    # 可能收到了恢复成功的消息，这与预期不符
                    restore_event = await self.receive_websocket_event(websocket, "session_restored", 5)
                    if restore_event:
                        print("❌ 意外收到恢复成功消息（预期应该过期）")
                        self.log_test_result(f"断连测试-{scenario_name}", False, 
                            "预期会话过期但恢复成功")
                        return False
                    else:
                        print("❌ 超时，未收到任何响应")
                        self.log_test_result(f"断连测试-{scenario_name}", False, "未收到响应")
                        return False
            
            else:
                print(f"❌ 未知的预期结果: {expected_result}")
                self.log_test_result(f"断连测试-{scenario_name}", False, f"未知预期结果: {expected_result}")
                return False
                
        except Exception as e:
            print(f"❌ 断连测试异常: {e}")
            self.log_test_result(f"断连测试-{scenario_name}", False, f"测试异常: {str(e)}")
            return False
        
        finally:
            # 清理连接
            if websocket:
                try:
                    await websocket.close()
                    print("🔌 测试连接已关闭")
                except:
                    pass
    
    async def test_multiple_disconnect_scenarios(self) -> Dict[str, Any]:
        """测试多个断连场景"""
        print("\n🔄 开始多场景断连测试...")
        
        if not self.enable_disconnect_test:
            print("⏭️ 断连测试已禁用，跳过")
            return {"enabled": False, "skipped": True}
        
        total_scenarios = len(self.disconnect_scenarios)
        if total_scenarios == 0:
            print("⚠️ 没有配置断连测试场景")
            return {"enabled": True, "total_scenarios": 0, "success": True}
        
        print(f"📊 共 {total_scenarios} 个断连场景需要测试")
        
        results = {}
        success_count = 0
        
        for i, scenario in enumerate(self.disconnect_scenarios, 1):
            scenario_name = scenario.get("name", f"场景{i}")
            print(f"\n{'='*50}")
            print(f"📋 场景 {i}/{total_scenarios}: {scenario_name}")
            print(f"{'='*50}")
            
            success = await self.test_single_disconnect_scenario(scenario)
            results[scenario_name] = success
            
            if success:
                success_count += 1
                print(f"✅ 场景 '{scenario_name}' 测试成功")
            else:
                print(f"❌ 场景 '{scenario_name}' 测试失败")
            
            # 场景间隔
            if i < total_scenarios:
                print(f"⏱️ 等待 {self.round_interval} 秒后进行下一场景...")
                await asyncio.sleep(self.round_interval)
        
        # 总结
        success_rate = (success_count / total_scenarios) * 100
        print(f"\n📈 断连场景测试结果: {success_count}/{total_scenarios} 成功 ({success_rate:.1f}%)")
        
        return {
            "enabled": True,
            "total_scenarios": total_scenarios,
            "success_count": success_count,
            "success_rate": success_rate,
            "results": results,
            "success": success_count == total_scenarios
        }
    
    async def test_repeated_disconnect_cycles(self) -> Dict[str, Any]:
        """测试重复断连周期（压力测试）"""
        print(f"\n🔄 开始重复断连周期测试（{self.test_rounds} 轮）...")
        
        round_results = []
        total_success = 0
        
        for round_num in range(1, self.test_rounds + 1):
            print(f"\n{'='*50}")
            print(f"📊 第 {round_num}/{self.test_rounds} 轮重复测试")
            print(f"{'='*50}")
            
            round_result = await self.test_multiple_disconnect_scenarios()
            round_results.append(round_result)
            
            if round_result.get("success", False):
                total_success += 1
                print(f"✅ 第 {round_num} 轮测试成功")
            else:
                print(f"❌ 第 {round_num} 轮测试失败")
            
            # 轮次间隔
            if round_num < self.test_rounds:
                print(f"⏱️ 等待 {self.round_interval} 秒后进行下一轮...")
                await asyncio.sleep(self.round_interval)
        
        # 总结
        total_success_rate = (total_success / self.test_rounds) * 100
        print(f"\n📈 重复断连测试总结: {total_success}/{self.test_rounds} 轮成功 ({total_success_rate:.1f}%)")
        
        return {
            "test_rounds": self.test_rounds,
            "success_count": total_success,
            "success_rate": total_success_rate,
            "round_results": round_results,
            "overall_success": total_success == self.test_rounds
        }
    
    async def run_all_tests(self) -> Dict[str, Any]:
        """运行所有断连恢复测试"""
        print("🔌 开始WebSocket断连恢复测试")
        print("=" * 60)
        print(f"测试配置:")
        print(f"  - 断连场景数: {len(self.disconnect_scenarios)}")
        print(f"  - 测试轮数: {self.test_rounds}")
        print(f"  - 重连超时: {self.reconnection_timeout}秒")
        print(f"  - 恢复超时: {self.recovery_timeout}秒")
        print(f"  - 后端地址: {self.base_url}")
        print("=" * 60)
        
        if not self.enable_disconnect_test:
            print("⏭️ 断连测试已禁用")
            return {"enabled": False, "success": True}
        
        try:
            # 执行重复断连周期测试
            test_results = await self.test_repeated_disconnect_cycles()
            
            # 最终总结
            print("\n" + "=" * 60)
            if test_results.get("overall_success", False):
                print("🎉 所有断连恢复测试通过！")
                print("✅ WebSocket断连恢复机制工作正常")
                print("✅ 会话持久化和恢复功能稳定")
                print("✅ 各种断连时长下的处理逻辑正确")
            else:
                print("❌ 断连恢复测试存在问题")
                print("⚠️ 建议检查:")
                print("   - 会话持久化时间配置")
                print("   - WebSocket重连逻辑")
                print("   - 会话恢复处理流程")
                print("   - 服务器端会话清理策略")
            print("=" * 60)
            
            return test_results
            
        except Exception as e:
            print(f"❌ 断连测试过程中发生异常: {e}")
            return {"success": False, "error": str(e)}


async def main(config_file: str = "remote_test_config.json"):
    """主测试函数"""
    tester = DisconnectRecoveryTester(config_file)
    
    try:
        test_results = await tester.run_all_tests()
        
        # 生成测试报告
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"disconnect_test_report_{timestamp}.json"
        tester.save_test_report(report_file)
        print(f"\n📊 测试报告已保存: {report_file}")
        
        return test_results.get("success", False)
        
    except KeyboardInterrupt:
        print("\n⚠️ 测试被用户中断")
        return False
    except Exception as e:
        print(f"\n❌ 测试过程中发生异常: {e}")
        return False


if __name__ == "__main__":
    config = sys.argv[1] if len(sys.argv) > 1 else "remote_test_config.json"
    success = asyncio.run(main(config))
    exit(0 if success else 1)