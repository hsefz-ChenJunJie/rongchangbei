#!/usr/bin/env python3
"""
远程API统一测试运行器
运行所有远程后端API测试并生成综合报告
"""

import asyncio
import sys
import os
import subprocess
import json
from datetime import datetime
from typing import Dict, List, Any


class RemoteTestRunner:
    """远程测试运行器"""
    
    def __init__(self, config_file: str = "remote_test_config.json"):
        self.config_file = config_file
        self.config = self._load_config()
        self.test_results = []
        
    def _load_config(self) -> Dict[str, Any]:
        """加载测试配置"""
        try:
            if not os.path.isabs(self.config_file):
                config_path = os.path.join(os.path.dirname(__file__), self.config_file)
            else:
                config_path = self.config_file
                
            with open(config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"❌ 配置文件未找到: {self.config_file}")
            print("💡 请确保配置文件存在，或复制 remote_test_config.example.json 为 remote_test_config.json")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"❌ 配置文件格式错误: {e}")
            sys.exit(1)
    
    def run_test_script(self, script_name: str, description: str) -> Dict[str, Any]:
        """运行单个测试脚本"""
        print(f"\n{'='*20} {description} {'='*20}")
        
        script_path = os.path.join(os.path.dirname(__file__), script_name)
        
        if not os.path.exists(script_path):
            result = {
                "script": script_name,
                "description": description,
                "success": False,
                "error": f"测试脚本不存在: {script_path}",
                "duration": 0
            }
            print(f"❌ 脚本不存在: {script_name}")
            return result
        
        start_time = datetime.now()
        
        try:
            # 运行测试脚本
            process = subprocess.run(
                [sys.executable, script_path, self.config_file],
                capture_output=True,
                text=True,
                timeout=300,  # 5分钟超时
                cwd=os.path.dirname(__file__)
            )
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            # 输出测试结果
            if process.stdout:
                print(process.stdout)
            
            if process.stderr:
                print("错误输出:")
                print(process.stderr)
            
            success = process.returncode == 0
            
            result = {
                "script": script_name,
                "description": description,
                "success": success,
                "return_code": process.returncode,
                "duration": duration,
                "stdout": process.stdout,
                "stderr": process.stderr,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat()
            }
            
            if success:
                print(f"✅ {description} 测试通过 ({duration:.1f}秒)")
            else:
                print(f"❌ {description} 测试失败 (返回码: {process.returncode})")
                
        except subprocess.TimeoutExpired:
            result = {
                "script": script_name,
                "description": description,
                "success": False,
                "error": "测试超时",
                "duration": 300
            }
            print(f"⏰ {description} 测试超时")
            
        except Exception as e:
            result = {
                "script": script_name,
                "description": description,
                "success": False,
                "error": str(e),
                "duration": 0
            }
            print(f"❌ {description} 测试异常: {e}")
        
        return result
    
    def test_server_connectivity(self) -> bool:
        """测试服务器连通性"""
        print("\n🔍 测试服务器连通性...")
        
        server_config = self.config["backend_server"]
        server_url = f"{server_config['base_url']}:{server_config['port']}"
        
        try:
            import requests
            response = requests.get(f"{server_url}/", timeout=10)
            if response.status_code == 200:
                print(f"✅ 服务器连通性正常: {server_url}")
                return True
            else:
                print(f"⚠️ 服务器响应状态码: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 服务器连接失败: {e}")
            return False
    
    def generate_comprehensive_report(self) -> str:
        """生成综合测试报告"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result["success"])
        failed_tests = total_tests - passed_tests
        
        total_duration = sum(result.get("duration", 0) for result in self.test_results)
        
        server_config = self.config["backend_server"]
        server_url = f"{server_config['base_url']}:{server_config['port']}"
        
        report_lines = [
            "=" * 80,
            "远程AI对话应用后端 - 综合测试报告",
            "=" * 80,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"测试服务器: {server_url}",
            f"配置文件: {self.config_file}",
            "",
            "📊 测试概要:",
            f"  总测试套件数: {total_tests}",
            f"  通过测试套件: {passed_tests}",
            f"  失败测试套件: {failed_tests}",
            f"  整体成功率: {(passed_tests/total_tests*100):.1f}%" if total_tests > 0 else "  整体成功率: 0%",
            f"  总测试时长: {total_duration:.1f}秒",
            "",
            "🧪 测试套件详情:",
        ]
        
        for i, result in enumerate(self.test_results, 1):
            status_emoji = "✅" if result["success"] else "❌"
            report_lines.append(f"  {i}. {status_emoji} {result['description']}")
            report_lines.append(f"     脚本: {result['script']}")
            report_lines.append(f"     耗时: {result.get('duration', 0):.1f}秒")
            
            if not result["success"]:
                error_msg = result.get("error", "未知错误")
                report_lines.append(f"     错误: {error_msg}")
            
            report_lines.append("")
        
        # 功能覆盖评估
        websocket_tested = any("websocket" in result["script"].lower() for result in self.test_results)
        conversation_tested = any("conversation" in result["script"].lower() for result in self.test_results)
        
        report_lines.extend([
            "🎯 功能覆盖评估:",
            f"  WebSocket连接测试: {'✅' if websocket_tested else '❌'}",
            f"  完整对话功能测试: {'✅' if conversation_tested else '❌'}",
            "",
            "🌟 服务状态评估:",
        ])
        
        if passed_tests == total_tests:
            report_lines.append("  🎉 所有测试完美通过！远程服务运行状态优秀！")
        elif passed_tests >= total_tests * 0.8:
            report_lines.append("  ✅ 大部分测试通过，远程服务运行状态良好")
        elif passed_tests >= total_tests * 0.6:
            report_lines.append("  ⚠️ 部分测试失败，远程服务可能存在问题")
        else:
            report_lines.append("  ❌ 多数测试失败，远程服务存在严重问题")
        
        report_lines.extend([
            "",
            "💡 建议:",
        ])
        
        if failed_tests > 0:
            report_lines.append("  1. 检查失败测试的错误信息")
            report_lines.append("  2. 验证远程服务器状态和配置")
            report_lines.append("  3. 确认网络连接稳定性")
            report_lines.append("  4. 检查API密钥和服务依赖")
        else:
            report_lines.append("  🎯 所有测试通过，可以进行生产部署！")
        
        report_lines.extend([
            "",
            "📞 技术支持:",
            "  如遇问题请检查:",
            "  - 服务器日志: 查看后端运行日志",
            "  - 网络连接: 确保测试环境可访问远程服务器",
            "  - 配置文件: 验证remote_test_config.json配置正确",
            "",
            "=" * 80,
            f"报告生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "=" * 80
        ])
        
        return "\n".join(report_lines)
    
    def print_event_summary_if_available(self):
        """如果可用，打印事件统计摘要"""
        try:
            # 尝试导入并运行简单测试来获取事件统计（演示用途）
            from remote_test_base import RemoteTestBase
            
            print("\n📋 事件日志功能说明:")
            print("  新增的详细事件日志系统将记录:")
            print("  • 每个发送和接收的WebSocket事件")
            print("  • 事件时间戳和响应时间")
            print("  • 数据大小和错误信息")
            print("  • 会话关联和事件序列")
            print("  • 敏感信息自动脱敏")
            print("\n  日志输出文件:")
            print("  • *_events.json - 纯事件日志数据")  
            print("  • event_log_*.log - 结构化日志文件（如启用）")
            print("  • 测试报告中包含事件统计信息")
            print("\n  配置选项:")
            print("  • enable_detailed_logging: 控制详细日志显示")
            print("  • enable_file_logging: 启用文件日志记录")
            print("  • log_level: 设置日志级别 (DEBUG/INFO/WARNING/ERROR)")
            print("  • show_list_items: 显示列表项详细内容")
            
        except Exception as e:
            print(f"⚠️ 无法显示事件统计: {e}")
    
    def run_all_tests(self):
        """运行所有远程测试"""
        print("🚀 开始远程AI对话应用后端综合测试")
        print("=" * 80)
        
        server_config = self.config["backend_server"]
        server_url = f"{server_config['base_url']}:{server_config['port']}"
        
        print(f"🌐 测试目标: {server_url}")
        print(f"⚙️ 配置文件: {self.config_file}")
        print(f"⏱️ 超时设置: 连接{self.config['test_settings']['connection_timeout']}秒, 响应{self.config['test_settings']['response_timeout']}秒")
        
        # 测试服务器连通性
        if not self.test_server_connectivity():
            print("\n❌ 服务器连通性测试失败，但继续执行其他测试...")
        
        # 定义测试套件
        test_suites = [
            ("test_websocket_features.py", "WebSocket功能测试"),
            ("test_conversation_features.py", "完整对话功能测试"),
            ("test_user_corpus_and_opinion_keywords.py", "档案回传测试"),
        ]
        
        print(f"\n📋 计划执行 {len(test_suites)} 个测试套件:")
        for script, description in test_suites:
            print(f"  - {description} ({script})")
        
        # 执行测试套件
        start_time = datetime.now()
        
        for script, description in test_suites:
            result = self.run_test_script(script, description)
            self.test_results.append(result)
        
        end_time = datetime.now()
        total_duration = (end_time - start_time).total_seconds()
        
        # 生成综合报告
        print("\n" + "="*80)
        print("📊 生成综合测试报告...")
        
        # 收集并显示事件统计（如果有的话）
        self.print_event_summary_if_available()
        
        report = self.generate_comprehensive_report()
        print(report)
        
        # 保存报告到文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"comprehensive_remote_test_report_{timestamp}.txt"
        
        try:
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report)
            print(f"\n📋 综合测试报告已保存: {report_file}")
        except Exception as e:
            print(f"❌ 保存报告失败: {e}")
        
        # 也保存JSON格式的详细数据
        json_report_file = f"comprehensive_remote_test_data_{timestamp}.json"
        try:
            detailed_data = {
                "test_config": {
                    "server_url": server_url,
                    "config_file": self.config_file,
                    "test_settings": self.config["test_settings"]
                },
                "test_summary": {
                    "total_suites": len(self.test_results),
                    "passed_suites": sum(1 for r in self.test_results if r["success"]),
                    "failed_suites": sum(1 for r in self.test_results if not r["success"]),
                    "total_duration": total_duration
                },
                "test_results": self.test_results,
                "generated_at": datetime.now().isoformat()
            }
            
            with open(json_report_file, 'w', encoding='utf-8') as f:
                json.dump(detailed_data, f, ensure_ascii=False, indent=2)
            print(f"📊 详细测试数据已保存: {json_report_file}")
        except Exception as e:
            print(f"❌ 保存详细数据失败: {e}")
        
        # 返回测试结果
        passed_tests = sum(1 for result in self.test_results if result["success"])
        success_rate = (passed_tests / len(self.test_results) * 100) if self.test_results else 0
        
        print(f"\n🏁 测试完成，总耗时: {total_duration:.1f}秒")
        print(f"📊 综合成功率: {success_rate:.1f}%")
        
        if success_rate == 100:
            print("🎉 恭喜！所有测试完美通过！")
            return True
        elif success_rate >= 80:
            print("✅ 大部分测试通过，系统基本正常")
            return True
        else:
            print("⚠️ 存在较多测试失败，请检查系统状态")
            return False


def main():
    """主函数"""
    # 解析命令行参数
    config_file = "remote_test_config.json"
    
    if len(sys.argv) > 1:
        if sys.argv[1] in ["-h", "--help"]:
            print("远程API综合测试运行器")
            print("用法:")
            print(f"  {sys.argv[0]} [配置文件路径]")
            print()
            print("示例:")
            print(f"  {sys.argv[0]}                           # 使用默认配置")
            print(f"  {sys.argv[0]} my_config.json            # 使用自定义配置")
            print()
            print("配置文件应包含服务器地址、端口、测试设置等信息")
            print("参考 remote_test_config.example.json 创建配置文件")
            return
        else:
            config_file = sys.argv[1]
    
    # 检查配置文件
    if not os.path.exists(config_file):
        print(f"❌ 配置文件不存在: {config_file}")
        print("💡 请复制 remote_test_config.example.json 为 remote_test_config.json 并修改配置")
        sys.exit(1)
    
    # 运行测试
    runner = RemoteTestRunner(config_file)
    success = runner.run_all_tests()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
