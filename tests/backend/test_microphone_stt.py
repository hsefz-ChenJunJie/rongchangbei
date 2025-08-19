#!/usr/bin/env python3
"""
麦克风语音转文字测试程序

该程序继承RemoteTestBase框架，用于测试AI对话应用后端的语音转文字功能：
1. 调用本地麦克风进行实时录音
2. 将音频流通过WebSocket发送至远程后端
3. 接收并显示语音识别结果
4. 集成现有测试框架的事件日志系统

使用方法：
    python test_microphone_stt.py

依赖安装：
    python install_microphone_test_deps.py

作者：AI Assistant
日期：2025-08-19
"""

import asyncio
import base64
import json
import time
from typing import Optional, Dict, Any
import pyaudio
import threading
import queue
from datetime import datetime

# 导入测试框架基础类
from remote_test_base import RemoteTestBase


class MicrophoneSTTTester(RemoteTestBase):
    """麦克风语音转文字测试类，继承RemoteTestBase"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        """初始化麦克风测试器"""
        super().__init__(config_file)
        
        # 音频录制配置（从配置文件读取，如果没有则使用默认值）
        microphone_config = self.config.get("microphone_test", {})
        self.audio_format = microphone_config.get("audio_format", pyaudio.paInt16)
        self.channels = microphone_config.get("channels", 1)
        self.sample_rate = microphone_config.get("sample_rate", 16000)
        self.chunk_size = microphone_config.get("chunk_size", 1024)
        self.record_seconds = microphone_config.get("record_seconds", 10)
        self.silence_threshold = microphone_config.get("silence_threshold", 500)
        self.silence_duration = microphone_config.get("silence_duration", 2.0)
        
        # 超时和重试配置
        self.transcription_timeout = microphone_config.get("transcription_timeout", 15.0)
        self.opinion_timeout = microphone_config.get("opinion_timeout", 10.0)
        self.transcription_max_attempts = microphone_config.get("transcription_max_attempts", 20)
        self.opinion_max_attempts = microphone_config.get("opinion_max_attempts", 15)
        self.progress_display_interval = microphone_config.get("progress_display_interval", 10)
        
        # 音频相关变量
        self.audio = None
        self.stream = None
        self.audio_queue = queue.Queue()
        self.is_recording = False
        self.websocket = None
        
        print(f"🎤 麦克风测试配置:")
        print(f"   采样率: {self.sample_rate}Hz")
        print(f"   声道数: {self.channels}")
        print(f"   录音时长: {self.record_seconds}秒")
        print(f"   音频块大小: {self.chunk_size}")
        print(f"   转录超时: {self.transcription_timeout}秒")
        print(f"   转录重试: {self.transcription_max_attempts}次")
        print(f"   进度显示间隔: 每{self.progress_display_interval}个音频块")
    
    def check_audio_devices(self) -> bool:
        """检查音频设备"""
        try:
            self.audio = pyaudio.PyAudio()
            device_count = self.audio.get_device_count()
            
            print(f"🎧 检测到 {device_count} 个音频设备")
            
            # 显示默认输入设备
            try:
                default_input = self.audio.get_default_input_device_info()
                print(f"🎤 默认输入设备: {default_input['name']}")
                print(f"📊 最大输入声道数: {default_input['maxInputChannels']}")
                print(f"🔊 默认采样率: {default_input['defaultSampleRate']}")
                
                # 检查设备是否支持我们的配置
                if default_input['maxInputChannels'] < self.channels:
                    print(f"⚠️  设备不支持 {self.channels} 声道，可能会有问题")
                
                return True
                
            except Exception as e:
                print(f"❌ 无法获取默认输入设备信息: {e}")
                return False
                
        except Exception as e:
            print(f"❌ PyAudio初始化失败: {e}")
            return False
    
    def start_recording(self):
        """开始录音"""
        try:
            if not self.audio:
                self.audio = pyaudio.PyAudio()
            
            self.stream = self.audio.open(
                format=self.audio_format,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                frames_per_buffer=self.chunk_size,
                stream_callback=self._audio_callback
            )
            
            self.is_recording = True
            self.stream.start_stream()
            print("🎤 开始录音...")
            
        except Exception as e:
            print(f"❌ 录音启动失败: {e}")
            raise
    
    def stop_recording(self):
        """停止录音"""
        if self.stream and self.is_recording:
            self.is_recording = False
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None
            print("⏹️ 录音已停止")
    
    def cleanup_audio(self):
        """清理音频资源"""
        self.stop_recording()
        if self.audio:
            self.audio.terminate()
            self.audio = None
    
    def _audio_callback(self, in_data, frame_count, time_info, status):
        """音频回调函数"""
        if self.is_recording:
            self.audio_queue.put(in_data)
        return (None, pyaudio.paContinue)
    
    async def send_microphone_audio_stream(self, session_id: str) -> bool:
        """发送麦克风音频流到服务器"""
        try:
            chunk_count = 0
            last_progress_time = time.time()
            
            print("🎵 开始发送音频流...")
            
            # 先发送message_start事件
            await self.send_websocket_event(self.websocket, "message_start", {
                "session_id": session_id,
                "sender": "测试用户"
            })
            
            while self.is_recording:
                try:
                    # 非阻塞获取音频数据
                    audio_data = self.audio_queue.get_nowait()
                    chunk_count += 1
                    
                    # 将音频数据编码为base64
                    audio_base64 = base64.b64encode(audio_data).decode('utf-8')
                    
                    # 使用框架的send_websocket_event方法
                    audio_event_data = {
                        "session_id": session_id,
                        "audio_chunk": audio_base64
                    }
                    
                    await self.send_websocket_event(self.websocket, "audio_stream", audio_event_data)
                    
                    # 进度显示（根据配置的间隔显示）
                    if chunk_count % self.progress_display_interval == 0:
                        current_time = time.time()
                        elapsed = current_time - last_progress_time
                        print(f"📊 已发送 {chunk_count} 个音频块，最近{self.progress_display_interval}块耗时: {elapsed:.2f}秒")
                        last_progress_time = current_time
                    
                except queue.Empty:
                    # 没有音频数据时短暂等待
                    await asyncio.sleep(0.01)
                    continue
                    
            # 发送message_end事件
            await self.send_websocket_event(self.websocket, "message_end", {
                "session_id": session_id
            })
            
            print(f"✅ 音频流发送完成，总共发送 {chunk_count} 个音频块")
            return True
            
        except Exception as e:
            print(f"❌ 发送音频流时出错: {e}")
            return False
    
    async def wait_for_transcription_result(self) -> Optional[str]:
        """等待语音转录结果"""
        print(f"⏳ 等待语音转录结果（最多{self.transcription_timeout}秒）...")
        
        # 使用框架的receive_any_websocket_event方法，自动处理status_update等干扰事件
        # 从配置文件读取max_attempts参数，因为语音处理过程中可能产生很多状态更新事件
        message_recorded_event = await self.receive_any_websocket_event(
            self.websocket, 
            ["message_recorded"], 
            self.transcription_timeout,
            max_attempts=self.transcription_max_attempts
        )
        
        if message_recorded_event:
            message_id = message_recorded_event["data"].get("message_id")
            print(f"✅ 消息已记录，ID: {message_id}")
            
            # 等待意见建议（可选）
            opinion_event = await self.receive_any_websocket_event(
                self.websocket, 
                ["opinion_suggestions"], 
                self.opinion_timeout,
                max_attempts=self.opinion_max_attempts
            )
            
            if opinion_event:
                suggestions = opinion_event["data"].get("suggestions", [])
                print(f"💡 收到意见建议: {', '.join(suggestions)}")
                return f"转录完成，消息ID: {message_id}，意见建议: {', '.join(suggestions)}"
            else:
                return f"转录完成，消息ID: {message_id}"
        else:
            print("⏰ 等待转录结果超时")
            return None
    
    async def test_microphone_to_stt(self) -> bool:
        """完整的麦克风语音转文字测试"""
        test_name = "麦克风语音转文字测试"
        print(f"\n🚀 开始 {test_name}")
        print("=" * 60)
        
        try:
            # 1. 检查音频设备
            if not self.check_audio_devices():
                self.log_test_result(test_name, False, "音频设备检查失败")
                return False
            
            # 2. 测试HTTP连接
            print("\n🔗 测试服务器连接...")
            if not await self.test_http_endpoint(self.server_config["health_endpoint"]):
                self.log_test_result(test_name, False, "服务器连接失败")
                return False
            
            # 3. 建立WebSocket连接
            print("\n🔌 建立WebSocket连接...")
            self.websocket = await self.connect_websocket()
            if not self.websocket:
                self.log_test_result(test_name, False, "WebSocket连接失败")
                return False
            
            # 4. 使用框架的start_conversation方法启动对话
            print("\n📞 启动对话会话...")
            session_id = await self.start_conversation(
                self.websocket,
                scenario_description="麦克风语音转文字测试",
                response_count=1
            )
            
            if not session_id:
                self.log_test_result(test_name, False, "会话创建失败")
                return False
            
            self.session_id = session_id
            print(f"✅ 会话创建成功，ID: {session_id}")
            
            # 5. 准备录音
            print(f"\n🎤 准备开始录音...")
            print(f"⏱️ 录音时长: {self.record_seconds} 秒")
            print("🗣️ 请清晰地说话，比如：'你好，这是一个语音转文字测试'")
            print("🔊 请确保在安静的环境中进行测试")
            
            # 等待用户准备
            input("\n按回车键开始录音...")
            
            # 6. 开始录音和音频流发送
            self.start_recording()
            
            # 启动音频流发送任务
            audio_task = asyncio.create_task(self.send_microphone_audio_stream(session_id))
            
            # 录音指定时间
            print(f"\n🔴 录音中... ({self.record_seconds}秒)")
            await asyncio.sleep(self.record_seconds)
            
            # 7. 停止录音
            self.stop_recording()
            
            # 等待音频流发送完成
            await audio_task
            
            # 8. 等待转录结果
            transcription_result = await self.wait_for_transcription_result()
            
            # 9. 结束对话
            await self.end_conversation(self.websocket, session_id)
            
            # 10. 评估测试结果
            if transcription_result:
                print(f"\n🎉 测试成功完成！")
                print(f"📝 转录结果: {transcription_result}")
                self.log_test_result(test_name, True, "麦克风语音转文字测试成功", {"transcription": transcription_result})
                return True
            else:
                print(f"\n❌ 测试失败：未收到转录结果")
                self.log_test_result(test_name, False, "未收到转录结果")
                return False
            
        except KeyboardInterrupt:
            print("\n⚠️ 用户中断测试")
            self.log_test_result(test_name, False, "用户中断")
            return False
        except Exception as e:
            print(f"\n❌ 测试过程中发生错误: {e}")
            self.log_test_result(test_name, False, f"测试异常: {str(e)}")
            return False
        finally:
            # 清理资源
            self.cleanup_audio()
            if self.websocket:
                await self.websocket.close()
    


async def main():
    """主函数"""
    print("🎯 麦克风语音转文字测试程序")
    print("基于远程API测试框架")
    print("=" * 60)
    
    try:
        # 检查PyAudio是否安装
        import pyaudio
    except ImportError:
        print("❌ PyAudio未安装，请先运行:")
        print("   python install_microphone_test_deps.py")
        return
    
    # 创建测试器实例
    try:
        tester = MicrophoneSTTTester()
    except Exception as e:
        print(f"❌ 测试器初始化失败: {e}")
        print("\n🔧 可能的解决方案:")
        print("1. 检查配置文件 remote_test_config.json 是否存在")
        print("2. 确认配置文件格式正确")
        return
    
    # 显示配置信息
    print(f"\n⚙️ 测试配置:")
    print(f"   目标服务器: {tester.base_url}")
    print(f"   WebSocket地址: {tester.ws_url}")
    
    # 询问是否继续
    user_input = input(f"\n是否使用以上配置开始测试？(Y/n): ").strip().lower()
    if user_input == 'n':
        print("测试已取消")
        return
    
    # 运行测试
    try:
        success = await tester.test_microphone_to_stt()
        
        # 生成测试报告
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"microphone_stt_test_report_{timestamp}.json"
        tester.save_test_report(report_file)
        print(f"\n📄 测试报告已保存: {report_file}")
        
        if success:
            print("\n✅ 麦克风语音转文字测试成功完成！")
            return True
        else:
            print("\n❌ 麦克风语音转文字测试失败")
            return False
            
    except KeyboardInterrupt:
        print("\n⚠️ 用户中断测试")
        return False
    except Exception as e:
        print(f"\n💥 程序异常: {e}")
        return False


if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n👋 程序已退出")
        exit(1)
    except Exception as e:
        print(f"\n💥 程序启动失败: {e}")
        print("\n🔧 可能的解决方案:")
        print("1. 确保已安装依赖: python install_microphone_test_deps.py")
        print("2. 检查麦克风权限")
        print("3. 确认后端服务正在运行")
        print("4. 检查配置文件 remote_test_config.json")
        exit(1)