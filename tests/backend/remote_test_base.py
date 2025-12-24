#!/usr/bin/env python3
"""
远程API测试基础类
为所有测试提供统一的配置加载和工具方法
"""

import json
import asyncio
import aiohttp
import websockets
import base64
import time
import os
import logging
from datetime import datetime
from typing import Dict, Any, Optional, List


class RemoteTestBase:
    """远程API测试基础类"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        """
        初始化测试基础类
        
        Args:
            config_file: 配置文件路径
        """
        self.config_file = config_file
        self.config = self._load_config()
        self.session_id = None
        self.test_results = []
        self.event_log = []  # 新增：事件日志记录
        self.event_sequence = 0  # 新增：事件序列号
        
        # 从配置中提取常用设置
        self.server_config = self.config["backend_server"]
        self.test_settings = self.config["test_settings"]
        self.scenarios = self.config["test_scenarios"]
        
        # 构建完整的服务器URL
        self.base_url = f"{self.server_config['base_url']}:{self.server_config['port']}"
        self.ws_url = f"ws://{self.server_config['base_url'].replace('http://', '').replace('https://', '')}:{self.server_config['port']}{self.server_config['websocket_endpoint']}"
        
        # 初始化事件日志系统
        self._setup_event_logger()
        
        print(f"🌐 目标服务器: {self.base_url}")
        print(f"🔌 WebSocket地址: {self.ws_url}")
    
    def _load_config(self) -> Dict[str, Any]:
        """加载测试配置"""
        try:
            # 支持相对路径和绝对路径
            if not os.path.isabs(self.config_file):
                config_path = os.path.join(os.path.dirname(__file__), self.config_file)
            else:
                config_path = self.config_file
                
            with open(config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"❌ 配置文件未找到: {self.config_file}")
            print("💡 请确保配置文件存在，或复制 remote_test_config.example.json 为 remote_test_config.json")
            raise
        except json.JSONDecodeError as e:
            print(f"❌ 配置文件格式错误: {e}")
            raise
    
    def _setup_event_logger(self):
        """设置事件日志记录器"""
        self.event_logger = logging.getLogger(f"{self.__class__.__name__}_events")
        
        # 如果已有处理器，不重复添加
        if self.event_logger.handlers:
            return
            
        # 配置日志级别
        log_level = self.test_settings.get("log_level", "INFO").upper()
        self.event_logger.setLevel(getattr(logging, log_level, logging.INFO))
        
        # 创建控制台处理器
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.DEBUG)
        
        # 创建格式器
        formatter = logging.Formatter(
            '%(asctime)s [%(name)s] %(levelname)s: %(message)s',
            datefmt='%H:%M:%S.%f'
        )
        console_handler.setFormatter(formatter)
        
        self.event_logger.addHandler(console_handler)
        
        # 如果配置了文件日志，也添加文件处理器
        if self.test_settings.get("enable_file_logging", False):
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            log_filename = f"event_log_{timestamp}.log"
            file_handler = logging.FileHandler(log_filename, encoding='utf-8')
            file_handler.setLevel(logging.DEBUG)
            file_handler.setFormatter(formatter)
            self.event_logger.addHandler(file_handler)
            print(f"📝 事件日志文件: {log_filename}")
    
    def _log_event(self, direction: str, event_type: str, event_data: Dict[str, Any], 
                   metadata: Optional[Dict[str, Any]] = None, success: bool = True):
        """记录事件到日志系统
        
        Args:
            direction: 事件方向 ('SEND' 或 'RECV')
            event_type: 事件类型
            event_data: 事件数据
            metadata: 附加元数据（如响应时间等）
            success: 事件是否成功
        """
        self.event_sequence += 1
        
        # 创建事件记录
        event_record = {
            "sequence": self.event_sequence,
            "timestamp": datetime.now().isoformat(),
            "direction": direction,
            "event_type": event_type,
            "success": success,
            "data": event_data.copy() if event_data else {},
            "metadata": metadata or {}
        }
        
        # 添加会话信息
        if self.session_id:
            event_record["session_id"] = self.session_id
        
        # 敏感信息脱敏处理
        self._sanitize_event_data(event_record["data"])
        
        # 存储到事件日志列表
        self.event_log.append(event_record)
        
        # 根据配置决定是否输出详细日志
        if self.test_settings.get("enable_detailed_logging", True):
            self._print_event_log(event_record)
        
        # 记录到日志系统
        log_message = self._format_event_log_message(event_record)
        if success:
            self.event_logger.info(log_message)
        else:
            self.event_logger.error(log_message)
    
    def _sanitize_event_data(self, data: Dict[str, Any]):
        """敏感信息脱敏处理"""
        sensitive_fields = ['audio_chunk', 'password', 'token', 'key']
        
        for field in sensitive_fields:
            if field in data:
                if field == 'audio_chunk':
                    # 音频数据只显示长度
                    original_length = len(data[field]) if data[field] else 0
                    data[field] = f"<audio_data_length:{original_length}>"
                else:
                    # 其他敏感字段用星号替代
                    data[field] = "***"
    
    def _format_event_log_message(self, event_record: Dict[str, Any]) -> str:
        """格式化事件日志消息"""
        direction = event_record["direction"]
        event_type = event_record["event_type"]
        success_icon = "✅" if event_record["success"] else "❌"
        
        # 基础消息
        message = f"{success_icon} [{direction}] {event_type}"
        
        # 添加会话ID
        if "session_id" in event_record:
            message += f" (session: {event_record['session_id'][:8]}...)"
        
        # 添加关键数据信息
        data = event_record["data"]
        if data:
            key_info = []
            if "sender" in data:
                key_info.append(f"sender={data['sender']}")
            if "response_count" in data:
                key_info.append(f"count={data['response_count']}")
            if "suggestions" in data and isinstance(data["suggestions"], list):
                key_info.append(f"suggestions_count={len(data['suggestions'])}")
            if "message_id" in data:
                key_info.append(f"msg_id={data['message_id']}")
            
            if key_info:
                message += f" [{', '.join(key_info)}]"
        
        # 添加元数据信息
        metadata = event_record.get("metadata", {})
        if "response_time" in metadata:
            message += f" (time: {metadata['response_time']}s)"
        if "timeout" in metadata:
            message += f" (timeout: {metadata['timeout']}s)"
        
        return message
    
    def _print_event_log(self, event_record: Dict[str, Any]):
        """打印格式化的事件日志到控制台"""
        sequence = event_record["sequence"]
        timestamp = datetime.fromisoformat(event_record["timestamp"]).strftime("%H:%M:%S.%f")[:-3]
        direction = event_record["direction"]
        event_type = event_record["event_type"]
        success = event_record["success"]
        
        # 方向图标和颜色
        if direction == "SEND":
            direction_icon = "📤"
            direction_color = "\033[36m"  # 青色
        else:
            direction_icon = "📥"
            direction_color = "\033[35m"  # 紫色
        
        # 成功状态图标
        status_icon = "✅" if success else "❌"
        
        # 重置颜色
        reset_color = "\033[0m"
        
        # 基础信息行
        print(f"\n{direction_color}┌─ [{sequence:03d}] {timestamp} {direction_icon} {direction} {status_icon}{reset_color}")
        print(f"{direction_color}├─ Event: {event_type}{reset_color}")
        
        # 会话信息
        if "session_id" in event_record:
            session_id = event_record["session_id"]
            print(f"{direction_color}├─ Session: {session_id}{reset_color}")
        
        # 数据信息
        data = event_record["data"]
        if data:
            print(f"{direction_color}├─ Data:{reset_color}")
            for key, value in data.items():
                if isinstance(value, list):
                    print(f"{direction_color}│  ├─ {key}: [{len(value)} items]{reset_color}")
                    if self.test_settings.get("show_list_items", False) and len(value) <= 3:
                        for i, item in enumerate(value):
                            truncated_item = str(item)[:50] + "..." if len(str(item)) > 50 else str(item)
                            print(f"{direction_color}│  │  └─ [{i}]: {truncated_item}{reset_color}")
                elif isinstance(value, dict):
                    print(f"{direction_color}│  ├─ {key}: {{{len(value)} fields}}{reset_color}")
                elif isinstance(value, str) and len(value) > 50:
                    truncated_value = value[:47] + "..."
                    print(f"{direction_color}│  ├─ {key}: \"{truncated_value}\"{reset_color}")
                else:
                    print(f"{direction_color}│  ├─ {key}: {value}{reset_color}")
        
        # 元数据信息
        metadata = event_record.get("metadata", {})
        if metadata:
            print(f"{direction_color}├─ Metadata:{reset_color}")
            for key, value in metadata.items():
                print(f"{direction_color}│  └─ {key}: {value}{reset_color}")
        
        print(f"{direction_color}└─────────────────────────────────{reset_color}")
    
    async def test_http_endpoint(self, endpoint: str, method: str = "GET", 
                                data: Optional[Dict] = None, 
                                timeout: Optional[int] = None) -> Dict[str, Any]:
        """
        测试HTTP端点
        
        Args:
            endpoint: API端点路径
            method: HTTP方法
            data: 请求数据
            timeout: 超时时间
            
        Returns:
            测试结果字典
        """
        url = f"{self.base_url}{endpoint}"
        timeout = timeout or self.test_settings["connection_timeout"]
        
        result = {
            "url": url,
            "method": method,
            "success": False,
            "status_code": None,
            "response_data": None,
            "error": None,
            "response_time": None
        }
        
        start_time = time.time()
        
        try:
            timeout_obj = aiohttp.ClientTimeout(total=timeout)
            async with aiohttp.ClientSession(timeout=timeout_obj) as session:
                if method.upper() == "GET":
                    async with session.get(url) as response:
                        result["status_code"] = response.status
                        result["response_data"] = await response.json()
                        result["success"] = response.status == 200
                elif method.upper() == "POST":
                    async with session.post(url, json=data) as response:
                        result["status_code"] = response.status
                        result["response_data"] = await response.json()
                        result["success"] = response.status == 200
                        
        except asyncio.TimeoutError:
            result["error"] = f"请求超时 (>{timeout}秒)"
        except aiohttp.ClientConnectorError as e:
            result["error"] = f"连接失败: {str(e)}"
        except aiohttp.ClientError as e:
            result["error"] = f"HTTP客户端错误: {str(e)}"
        except Exception as e:
            result["error"] = f"未知错误: {str(e)}"
        finally:
            result["response_time"] = round(time.time() - start_time, 3)
        
        # 记录HTTP请求事件
        http_metadata = {
            "method": method,
            "timeout": timeout,
            "response_time": result["response_time"],
            "status_code": result["status_code"]
        }
        
        if result["error"]:
            http_metadata["error"] = result["error"]
            
        self._log_event("HTTP", f"http_{method.lower()}", 
                       {"url": endpoint, "data": data} if data else {"url": endpoint}, 
                       http_metadata, result["success"])
        
        return result
    
    async def connect_websocket(self, timeout: Optional[int] = None) -> Optional[websockets.WebSocketServerProtocol]:
        """
        连接WebSocket
        
        Args:
            timeout: 连接超时时间
            
        Returns:
            WebSocket连接对象或None
        """
        timeout = timeout or self.test_settings["connection_timeout"]
        
        start_time = time.time()
        success = False
        error_msg = None
        websocket = None
        
        try:
            print(f"🔌 正在连接WebSocket: {self.ws_url}")
            websocket = await asyncio.wait_for(
                websockets.connect(self.ws_url),
                timeout=timeout
            )
            success = True
            print("✅ WebSocket连接成功")
        except asyncio.TimeoutError:
            error_msg = f"连接超时 (>{timeout}秒)"
            print(f"❌ WebSocket{error_msg}")
        except Exception as e:
            error_msg = f"连接异常: {str(e)}"
            print(f"❌ WebSocket连接失败: {e}")
        
        # 记录连接事件
        response_time = round(time.time() - start_time, 3)
        metadata = {
            "timeout": timeout,
            "response_time": response_time,
            "websocket_url": self.ws_url
        }
        
        if not success:
            metadata["error"] = error_msg
            
        self._log_event("CONN", "websocket_connect", {}, metadata, success)
        
        return websocket
    
    async def send_websocket_event(self, websocket: websockets.WebSocketServerProtocol, 
                                  event_type: str, event_data: Dict[str, Any],
                                  timeout: Optional[int] = None) -> bool:
        """
        发送WebSocket事件
        
        Args:
            websocket: WebSocket连接
            event_type: 事件类型
            event_data: 事件数据
            timeout: 发送超时时间
            
        Returns:
            发送是否成功
        """
        timeout = timeout or self.test_settings["response_timeout"]
        
        message = {
            "type": event_type,
            "data": event_data
        }
        
        start_time = time.time()
        success = False
        error_msg = None
        
        try:
            message_json = json.dumps(message, ensure_ascii=False)
            await asyncio.wait_for(
                websocket.send(message_json),
                timeout=timeout
            )
            success = True
            
        except asyncio.TimeoutError:
            error_msg = f"发送超时 (>{timeout}秒)"
        except Exception as e:
            error_msg = f"发送异常: {str(e)}"
        
        # 记录事件日志
        response_time = round(time.time() - start_time, 3)
        metadata = {
            "timeout": timeout,
            "response_time": response_time,
            "message_size": len(message_json) if 'message_json' in locals() else 0
        }
        
        if not success:
            metadata["error"] = error_msg
            
        self._log_event("SEND", event_type, event_data, metadata, success)
        
        if not success:
            print(f"❌ 发送事件失败 {event_type}: {error_msg}")
            
        return success
    
    async def receive_websocket_event(self, websocket: websockets.WebSocketServerProtocol,
                                     expected_type: Optional[str] = None,
                                     timeout: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """
        接收WebSocket事件
        
        Args:
            websocket: WebSocket连接
            expected_type: 期望的事件类型
            timeout: 接收超时时间
            
        Returns:
            接收到的事件数据或None
        """
        timeout = timeout or self.test_settings["response_timeout"]
        
        start_time = time.time()
        success = False
        event = None
        event_type = "unknown"
        event_data = {}
        error_msg = None
        
        try:
            message = await asyncio.wait_for(
                websocket.recv(),
                timeout=timeout
            )
            
            event = json.loads(message)
            event_type = event.get("type", "unknown")
            event_data = event.get("data", {})
            success = True
            
            # 检查事件类型是否符合期望
            type_mismatch = expected_type and event_type != expected_type
            if type_mismatch:
                print(f"⚠️ 期望事件类型 {expected_type}，但接收到 {event_type}")
            
        except asyncio.TimeoutError:
            error_msg = f"接收超时 (>{timeout}秒)"
            if expected_type:
                event_type = expected_type + "(timeout)"
        except json.JSONDecodeError as e:
            error_msg = f"JSON解析失败: {str(e)}"
        except Exception as e:
            error_msg = f"接收异常: {str(e)}"
        
        # 记录事件日志
        response_time = round(time.time() - start_time, 3)
        metadata = {
            "timeout": timeout,
            "response_time": response_time,
            "expected_type": expected_type
        }
        
        if success:
            metadata["message_size"] = len(message)
            if expected_type and event_type != expected_type:
                metadata["type_mismatch"] = True
        else:
            metadata["error"] = error_msg
            
        self._log_event("RECV", event_type, event_data, metadata, success)
        
        if not success:
            if expected_type:
                print(f"❌ 接收事件失败 (期望: {expected_type}): {error_msg}")
            else:
                print(f"❌ 接收事件失败: {error_msg}")
            
        return event
    
    async def receive_any_websocket_event(self, websocket: websockets.WebSocketServerProtocol,
                                         expected_types: Optional[List[str]] = None,
                                         timeout: Optional[int] = None,
                                         max_attempts: int = 3) -> Optional[Dict[str, Any]]:
        """
        接收WebSocket事件，支持多种期望的事件类型
        
        Args:
            websocket: WebSocket连接
            expected_types: 期望的事件类型列表
            timeout: 单次接收超时时间
            max_attempts: 最大尝试次数
            
        Returns:
            接收到的事件数据或None
        """
        timeout = timeout or self.test_settings["response_timeout"]
        
        for attempt in range(max_attempts):
            try:
                event = await self.receive_websocket_event(websocket, None, timeout)
                if event:
                    event_type = event.get("type", "unknown")
                    
                    # 如果没有指定期望类型，则接受任何事件
                    if not expected_types:
                        return event
                    
                    # 检查是否为期望的事件类型之一
                    if event_type in expected_types:
                        return event
                    
                    # 如果不是期望的类型但是状态更新，继续等待
                    if event_type == "status_update":
                        print(f"⏳ 收到状态更新: {event.get('data', {}).get('status', 'unknown')}，继续等待目标事件...")
                        continue
                
                # 如果没有收到事件，减少剩余尝试次数
                if attempt < max_attempts - 1:
                    print(f"⏳ 未收到预期事件，继续尝试 ({attempt + 1}/{max_attempts})")
                    await asyncio.sleep(1)  # 短暂等待
                    
            except Exception as e:
                print(f"⚠️ 接收事件异常 (尝试 {attempt + 1}/{max_attempts}): {str(e)}")
                if attempt < max_attempts - 1:
                    await asyncio.sleep(1)
        
        # 所有尝试都失败了
        expected_str = f" (期望: {expected_types})" if expected_types else ""
        print(f"❌ 在 {max_attempts} 次尝试后仍未收到预期事件{expected_str}")
        return None
    
    def generate_mock_audio_chunk(self) -> str:
        """生成模拟音频数据块"""
        # 生成一些模拟的音频数据（实际项目中会是真实的音频数据）
        mock_audio = b"mock_audio_data_" + str(int(time.time() * 1000)).encode()
        return base64.b64encode(mock_audio).decode()
    
    async def start_conversation(self, websocket: websockets.WebSocketServerProtocol,
                                scenario_description: Optional[str] = None,
                                response_count: Optional[int] = None,
                                history_messages: Optional[List[Dict]] = None,
                                user_profile: Optional[Dict[str, Any]] = None,
                                target_profile: Optional[Dict[str, Any]] = None) -> Optional[str]:
        """
        开始对话
        
        Args:
            websocket: WebSocket连接
            scenario_description: 对话场景描述
            response_count: 回答数量
            history_messages: 历史消息
            user_profile: 用户档案
            target_profile: 对话对象档案
            
        Returns:
            会话ID或None
        """
        event_data = {
            "scenario_description": scenario_description or self.scenarios["scenario_description"],
            "response_count": response_count or self.scenarios["response_count"]
        }
        
        if history_messages:
            event_data["history_messages"] = history_messages
        if user_profile:
            event_data["user_profile"] = user_profile
        if target_profile:
            event_data["target_profile"] = target_profile
        
        # 发送对话开始事件
        success = await self.send_websocket_event(websocket, "conversation_start", event_data)
        if not success:
            return None
        
        # 接收会话创建确认
        response = await self.receive_websocket_event(websocket, "session_created")
        if response and response.get("type") == "session_created":
            session_id = response["data"]["session_id"]
            self.session_id = session_id
            print(f"✅ 会话创建成功: {session_id}")
            return session_id
        
        return None
    
    async def send_audio_message(self, websocket: websockets.WebSocketServerProtocol,
                                session_id: str, sender: str,
                                audio_chunks: Optional[int] = None) -> bool:
        """
        发送音频消息
        
        Args:
            websocket: WebSocket连接
            session_id: 会话ID
            sender: 发送者
            audio_chunks: 音频块数量
            
        Returns:
            是否成功
        """
        audio_chunks = audio_chunks or self.test_settings["test_audio_chunks"]
        
        # 发送消息开始事件
        success = await self.send_websocket_event(websocket, "message_start", {
            "session_id": session_id,
            "sender": sender
        })
        if not success:
            return False
        
        # 发送音频流
        for i in range(audio_chunks):
            audio_chunk = self.generate_mock_audio_chunk()
            success = await self.send_websocket_event(websocket, "audio_stream", {
                "session_id": session_id,
                "audio_chunk": audio_chunk
            })
            if not success:
                return False
            
            # 模拟音频流间隔
            await asyncio.sleep(0.1)
        
        # 发送消息结束事件
        success = await self.send_websocket_event(websocket, "message_end", {
            "session_id": session_id
        })
        
        return success
    
    async def end_conversation(self, websocket: websockets.WebSocketServerProtocol,
                              session_id: str) -> bool:
        """
        结束对话
        
        Args:
            websocket: WebSocket连接
            session_id: 会话ID
            
        Returns:
            是否成功
        """
        return await self.send_websocket_event(websocket, "conversation_end", {
            "session_id": session_id
        })
    
    def log_test_result(self, test_name: str, success: bool, 
                       details: Optional[str] = None, 
                       data: Optional[Dict] = None):
        """记录测试结果"""
        result = {
            "test_name": test_name,
            "success": success,
            "timestamp": datetime.now().isoformat(),
            "details": details,
            "data": data
        }
        self.test_results.append(result)
        
        status = "✅" if success else "❌"
        print(f"{status} {test_name}")
        if details:
            print(f"   {details}")
    
    def get_test_summary(self) -> Dict[str, Any]:
        """获取测试摘要"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result["success"])
        failed_tests = total_tests - passed_tests
        
        return {
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": failed_tests,
            "success_rate": round(passed_tests / total_tests * 100, 1) if total_tests > 0 else 0,
            "results": self.test_results
        }
    
    def save_test_report(self, filename: Optional[str] = None):
        """保存测试报告"""
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"remote_test_report_{timestamp}.json"
        
        report = {
            "test_config": {
                "server_url": self.base_url,
                "websocket_url": self.ws_url,
                "test_settings": self.test_settings
            },
            "test_summary": self.get_test_summary(),
            "generated_at": datetime.now().isoformat()
        }
        
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            print(f"📋 测试报告已保存: {filename}")
        except Exception as e:
            print(f"❌ 保存测试报告失败: {e}")


if __name__ == "__main__":
    print("📚 这是远程API测试基础类，请导入到具体的测试脚本中使用")
    print("例如：")
    print("from remote_test_base import RemoteTestBase")
