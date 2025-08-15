#!/usr/bin/env python3
"""
运行所有后端修复测试
综合测试音频流处理和response_count_update的修复效果
"""

import asyncio
import subprocess
import sys
import time
import logging
from pathlib import Path

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class TestSuite:
    def __init__(self):
        self.test_dir = Path(__file__).parent
        self.backend_dir = self.test_dir.parent.parent / "backend"
        self.results = {}
        
    def check_server_running(self):
        """检查后端服务是否运行"""
        try:
            import requests
            response = requests.get("http://localhost:8000/", timeout=5)
            if response.status_code == 200:
                logger.info("✅ 后端服务正在运行")
                return True
        except Exception as e:
            logger.error(f"❌ 后端服务未运行: {e}")
            return False
    
    def start_backend_server(self):
        """启动后端服务"""
        logger.info("正在启动后端服务...")
        
        # 构建启动命令
        cmd = [
            "bash", "-c", 
            f"cd {self.backend_dir} && source ~/.zshrc && mamba activate rongchang && PYTHONPATH=. python app/main.py"
        ]
        
        try:
            # 启动服务（后台运行）
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # 等待服务启动
            logger.info("等待服务启动...")
            for i in range(30):  # 最多等待30秒
                if self.check_server_running():
                    logger.info("✅ 后端服务启动成功")
                    return process
                time.sleep(1)
            
            logger.error("❌ 后端服务启动超时")
            process.terminate()
            return None
            
        except Exception as e:
            logger.error(f"❌ 启动后端服务失败: {e}")
            return None
    
    async def run_test(self, test_name, test_file):
        """运行单个测试"""
        logger.info(f"\n{'='*70}")
        logger.info(f"开始运行测试: {test_name}")
        logger.info(f"测试文件: {test_file}")
        logger.info(f"{'='*70}")
        
        try:
            # 构建测试命令
            cmd = [
                "bash", "-c",
                f"cd {self.backend_dir} && source ~/.zshrc && mamba activate rongchang && python {test_file}"
            ]
            
            # 运行测试
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60  # 60秒超时
            )
            
            # 记录结果
            success = result.returncode == 0
            self.results[test_name] = {
                "success": success,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
            
            # 显示结果
            if success:
                logger.info(f"✅ {test_name} 测试通过")
            else:
                logger.error(f"❌ {test_name} 测试失败 (退出码: {result.returncode})")
            
            # 显示输出（最后几行）
            if result.stdout:
                stdout_lines = result.stdout.strip().split('\n')
                logger.info("标准输出（最后5行）:")
                for line in stdout_lines[-5:]:
                    logger.info(f"  {line}")
            
            if result.stderr and not success:
                stderr_lines = result.stderr.strip().split('\n')
                logger.error("错误输出（最后5行）:")
                for line in stderr_lines[-5:]:
                    logger.error(f"  {line}")
            
            return success
            
        except subprocess.TimeoutExpired:
            logger.error(f"❌ {test_name} 测试超时")
            self.results[test_name] = {"success": False, "error": "timeout"}
            return False
        except Exception as e:
            logger.error(f"❌ {test_name} 测试异常: {e}")
            self.results[test_name] = {"success": False, "error": str(e)}
            return False
    
    def print_summary(self):
        """打印测试总结"""
        logger.info(f"\n{'='*70}")
        logger.info("测试总结报告")
        logger.info(f"{'='*70}")
        
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results.values() if r["success"])
        
        for test_name, result in self.results.items():
            status = "✅ 通过" if result["success"] else "❌ 失败"
            logger.info(f"{test_name:30} {status}")
        
        logger.info(f"\n总计: {passed_tests}/{total_tests} 通过")
        
        if passed_tests == total_tests:
            logger.info("🎉 所有测试通过！修复完全成功！")
            return True
        else:
            logger.error("❌ 部分测试失败，需要进一步检查")
            return False
    
    async def run_all_tests(self):
        """运行所有测试"""
        logger.info("开始运行荣昶杯后端修复测试套件")
        
        # 检查服务器
        server_process = None
        if not self.check_server_running():
            logger.info("后端服务未运行，尝试启动...")
            server_process = self.start_backend_server()
            if not server_process:
                logger.error("无法启动后端服务，测试终止")
                return False
        
        try:
            # 定义测试列表
            tests = [
                ("音频流处理修复测试", self.test_dir / "test_audio_stream_fix.py"),
                ("Response Count修复测试", self.test_dir / "test_response_count_fix.py"),
            ]
            
            # 运行测试
            for test_name, test_file in tests:
                await self.run_test(test_name, test_file)
                await asyncio.sleep(2)  # 测试间隔
            
            # 打印总结
            return self.print_summary()
            
        finally:
            # 清理：停止服务器（如果是我们启动的）
            if server_process:
                logger.info("正在停止后端服务...")
                server_process.terminate()
                try:
                    server_process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server_process.kill()
                logger.info("✅ 后端服务已停止")

async def main():
    """主函数"""
    try:
        # 检查依赖
        try:
            import websockets
            import requests
        except ImportError as e:
            logger.error(f"缺少依赖库: {e}")
            logger.error("请安装: pip install websockets requests")
            return False
        
        # 运行测试套件
        suite = TestSuite()
        result = await suite.run_all_tests()
        
        # 生成测试报告
        report_file = Path(__file__).parent / "test_report.txt"
        with open(report_file, "w", encoding="utf-8") as f:
            f.write("荣昶杯AI对话应用后端修复测试报告\n")
            f.write("="*50 + "\n")
            f.write(f"测试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            for test_name, result_data in suite.results.items():
                f.write(f"测试: {test_name}\n")
                f.write(f"结果: {'通过' if result_data['success'] else '失败'}\n")
                if result_data.get("stdout"):
                    f.write(f"输出:\n{result_data['stdout']}\n")
                if result_data.get("stderr"):
                    f.write(f"错误:\n{result_data['stderr']}\n")
                f.write("-" * 30 + "\n")
        
        logger.info(f"详细测试报告已保存到: {report_file}")
        
        return result
        
    except Exception as e:
        logger.error(f"测试套件运行异常: {e}")
        return False

if __name__ == "__main__":
    # 运行测试套件
    result = asyncio.run(main())
    sys.exit(0 if result else 1)