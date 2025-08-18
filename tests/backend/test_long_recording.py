#!/usr/bin/env python3
"""
长时间录音测试脚本
测试1分半连续录音是否会导致WebSocket断连问题
"""

import asyncio
import sys
import os
import json
import base64
import time
from datetime import datetime, timedelta
from typing import Optional

# 添加项目路径
sys.path.append(os.path.dirname(__file__))
from remote_test_base import RemoteTestBase


class LongRecordingTester(RemoteTestBase):
    """长时间录音测试器"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        super().__init__(config_file)
        self.recording_duration = 90  # 1分半（90秒）
        self.chunk_interval = 0.1     # 每100ms发送一个音频块
        self.chunk_size = 1024        # 每个音频块1KB
        
    def generate_realistic_audio_chunk(self, chunk_id: int) -> str:
        """生成更真实的音频数据块"""
        # 模拟音频数据：包含一些变化，不是纯零
        audio_data = bytearray(self.chunk_size)
        for i in range(self.chunk_size):
            # 生成简单的波形数据
            audio_data[i] = (chunk_id + i) % 256
        
        return base64.b64encode(audio_data).decode('utf-8')
    
    async def test_long_recording_session(self) -> bool:
        """测试长时间录音会话"""
        print(f"🎙️ 开始长时间录音测试（{self.recording_duration}秒）...")
        
        websocket = None
        session_id = None
        start_time = time.time()
        chunks_sent = 0
        connection_lost = False
        
        try:
            # 1. 建立连接
            print("🔌 建立WebSocket连接...")
            websocket = await self.connect_websocket()
            if not websocket:
                self.log_test_result("长时间录音测试", False, "无法建立WebSocket连接")
                return False
            
            # 2. 开始对话
            print("🆕 开始新对话...")
            session_id = await self.start_conversation(websocket, 
                scenario_description="长时间录音稳定性测试", 
                response_count=1)
            if not session_id:
                self.log_test_result("长时间录音测试", False, "无法创建会话")
                return False
            
            print(f"✅ 会话创建成功: {session_id}")
            
            # 3. 开始消息录制
            print("📝 发送消息开始事件...")
            success = await self.send_websocket_event(websocket, "message_start", {
                "session_id": session_id,
                "sender": "长时间录音测试用户"
            })
            if not success:
                self.log_test_result("长时间录音测试", False, "无法发送message_start事件")
                return False
            
            # 等待状态更新
            event = await self.receive_websocket_event(websocket, "status_update", 10)
            if not event or event["data"].get("status") != "recording_message":
                self.log_test_result("长时间录音测试", False, "未收到recording_message状态")
                return False
            
            print("✅ 进入录音状态，开始长时间录音...")
            
            # 4. 持续发送音频流（90秒）
            total_chunks = int(self.recording_duration / self.chunk_interval)
            print(f"📊 预计发送 {total_chunks} 个音频块，每个 {self.chunk_size} 字节")
            
            recording_start = time.time()
            last_progress_time = recording_start
            
            for chunk_id in range(total_chunks):
                try:
                    current_time = time.time()
                    elapsed = current_time - recording_start
                    
                    # 每10秒显示一次进度
                    if current_time - last_progress_time >= 10:
                        progress = (elapsed / self.recording_duration) * 100
                        print(f"🎙️ 录音进度: {elapsed:.1f}s / {self.recording_duration}s ({progress:.1f}%)")
                        print(f"   已发送: {chunks_sent} 个音频块")
                        print(f"   连接状态: {'正常' if websocket and not websocket.closed else '异常'}")
                        last_progress_time = current_time
                    
                    # 检查连接状态
                    if websocket.closed:
                        connection_lost = True
                        lost_time = elapsed
                        print(f"❌ 连接在 {lost_time:.1f} 秒后断开！")
                        break
                    
                    # 生成并发送音频块
                    audio_chunk = self.generate_realistic_audio_chunk(chunk_id)
                    success = await self.send_websocket_event(websocket, "audio_stream", {
                        "session_id": session_id,
                        "audio_chunk": audio_chunk
                    })
                    
                    if not success:
                        connection_lost = True
                        lost_time = elapsed
                        print(f"❌ 音频块发送失败，连接在 {lost_time:.1f} 秒后中断！")
                        break
                    
                    chunks_sent += 1
                    
                    # 控制发送间隔
                    await asyncio.sleep(self.chunk_interval)
                    
                except Exception as e:
                    connection_lost = True
                    lost_time = time.time() - recording_start
                    print(f"❌ 录音过程中发生异常 ({lost_time:.1f}s): {e}")
                    break
            
            recording_end = time.time()
            total_recording_time = recording_end - recording_start
            
            # 5. 结果分析
            if connection_lost:
                print(f"\n❌ 长时间录音测试失败")
                print(f"   录音时长: {total_recording_time:.1f}s / {self.recording_duration}s")
                print(f"   发送音频块: {chunks_sent} / {total_chunks}")
                print(f"   连接状态: 中断")
                
                self.log_test_result("长时间录音测试", False, 
                    f"连接在 {total_recording_time:.1f}s 后中断，共发送 {chunks_sent} 个音频块")
                return False
            
            else:
                print(f"\n✅ 音频流发送完成")
                print(f"   录音时长: {total_recording_time:.1f}s")
                print(f"   发送音频块: {chunks_sent}")
                print(f"   平均发送速率: {chunks_sent/total_recording_time:.1f} 块/秒")
                
                # 6. 结束消息
                print("🔚 发送消息结束事件...")
                success = await self.send_websocket_event(websocket, "message_end", {
                    "session_id": session_id
                })
                
                if success:
                    # 等待消息记录确认
                    event = await self.receive_websocket_event(websocket, "message_recorded", 15)
                    if event:
                        message_id = event["data"].get("message_id")
                        print(f"✅ 消息记录成功: {message_id}")
                        
                        print(f"\n🎉 长时间录音测试成功！")
                        print(f"   ✅ 连接稳定性: 90秒无断连")
                        print(f"   ✅ 音频流处理: {chunks_sent} 个音频块全部成功")
                        print(f"   ✅ 消息处理: 完整的录音消息流程")
                        
                        self.log_test_result("长时间录音测试", True, 
                            f"90秒录音成功，发送 {chunks_sent} 个音频块，连接稳定")
                        return True
                    else:
                        self.log_test_result("长时间录音测试", False, "录音完成但消息记录失败")
                        return False
                else:
                    self.log_test_result("长时间录音测试", False, "无法发送message_end事件")
                    return False
                    
        except Exception as e:
            elapsed = time.time() - start_time
            print(f"❌ 测试过程中发生异常 ({elapsed:.1f}s): {e}")
            self.log_test_result("长时间录音测试", False, f"测试异常: {str(e)}")
            return False
            
        finally:
            # 清理连接
            if websocket and not websocket.closed:
                try:
                    await websocket.close()
                    print("🔌 WebSocket连接已关闭")
                except:
                    pass
    
    async def test_multiple_long_recordings(self) -> bool:
        """测试多次长时间录音（压力测试）"""
        print("\n🔄 开始多次长时间录音压力测试...")
        
        test_rounds = 3  # 测试3轮
        success_count = 0
        
        for round_num in range(1, test_rounds + 1):
            print(f"\n📊 第 {round_num}/{test_rounds} 轮测试")
            print("=" * 50)
            
            success = await self.test_long_recording_session()
            if success:
                success_count += 1
                print(f"✅ 第 {round_num} 轮测试成功")
            else:
                print(f"❌ 第 {round_num} 轮测试失败")
            
            # 轮次间隔
            if round_num < test_rounds:
                print("⏱️ 等待5秒后进行下一轮测试...")
                await asyncio.sleep(5)
        
        # 总结
        print(f"\n📈 多轮测试结果: {success_count}/{test_rounds} 成功")
        
        if success_count == test_rounds:
            print("🎉 所有轮次测试成功！长时间录音功能稳定！")
            self.log_test_result("多轮长时间录音测试", True, f"{success_count}/{test_rounds} 轮成功")
            return True
        else:
            print(f"⚠️ 部分轮次失败，稳定性需要改进")
            self.log_test_result("多轮长时间录音测试", False, f"仅 {success_count}/{test_rounds} 轮成功")
            return False
    
    async def run_all_tests(self) -> bool:
        """运行所有长时间录音测试"""
        print("🎙️ 开始长时间录音稳定性测试")
        print("=" * 60)
        print(f"测试配置:")
        print(f"  - 录音时长: {self.recording_duration} 秒")
        print(f"  - 音频块大小: {self.chunk_size} 字节")
        print(f"  - 发送间隔: {self.chunk_interval} 秒")
        print(f"  - 后端地址: {self.config['backend_host']}:{self.config['backend_port']}")
        print("=" * 60)
        
        all_success = True
        
        # 测试1: 单次长时间录音
        success = await self.test_long_recording_session()
        all_success = all_success and success
        
        # 测试2: 多轮压力测试
        success = await self.test_multiple_long_recordings()
        all_success = all_success and success
        
        # 最终结果
        print("\n" + "=" * 60)
        if all_success:
            print("🎉 所有长时间录音测试通过！")
            print("✅ WebSocket连接在90秒连续音频流下保持稳定")
            print("✅ 后端能够正确处理大量音频数据块")
            print("✅ 消息流程在长时间录音下正常工作")
        else:
            print("❌ 长时间录音测试存在问题")
            print("⚠️ 建议检查:")
            print("   - WebSocket连接超时设置")
            print("   - 服务器内存使用情况")
            print("   - 音频流处理逻辑")
        print("=" * 60)
        
        return all_success


async def main():
    """主测试函数"""
    tester = LongRecordingTester()
    
    try:
        success = await tester.run_all_tests()
        
        # 生成测试报告
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"long_recording_test_report_{timestamp}.json"
        tester.generate_test_report(report_file)
        print(f"\n📊 测试报告已保存: {report_file}")
        
        return success
        
    except KeyboardInterrupt:
        print("\n⚠️ 测试被用户中断")
        return False
    except Exception as e:
        print(f"\n❌ 测试过程中发生异常: {e}")
        return False


if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)