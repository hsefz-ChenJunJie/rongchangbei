#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
麦克风测试依赖安装脚本

该脚本用于自动安装麦克风语音转文字测试所需的依赖包，
处理不同操作系统的兼容性问题。

使用方法：
    python install_microphone_test_deps.py

作者：AI Assistant  
日期：2025-08-19
"""

import os
import sys
import subprocess
import platform


class DependencyInstaller:
    """依赖安装器"""
    
    def __init__(self):
        self.system = platform.system().lower()
        self.python_cmd = sys.executable
        
    def print_info(self, message: str):
        """打印信息"""
        print(f"ℹ️  {message}")
        
    def print_success(self, message: str):
        """打印成功信息"""
        print(f"✅ {message}")
        
    def print_error(self, message: str):
        """打印错误信息"""
        print(f"❌ {message}")
        
    def print_warning(self, message: str):
        """打印警告信息"""
        print(f"⚠️  {message}")
    
    def run_command(self, command: list, description: str) -> bool:
        """运行命令"""
        try:
            self.print_info(f"执行: {description}")
            result = subprocess.run(command, capture_output=True, text=True, check=True)
            return True
        except subprocess.CalledProcessError as e:
            self.print_error(f"{description} 失败")
            self.print_error(f"错误输出: {e.stderr}")
            return False
        except Exception as e:
            self.print_error(f"{description} 异常: {e}")
            return False
    
    def install_system_dependencies(self) -> bool:
        """安装系统级依赖"""
        self.print_info("检查系统级依赖...")
        
        if self.system == "darwin":  # macOS
            return self._install_macos_deps()
        elif self.system == "linux":
            return self._install_linux_deps()
        elif self.system == "windows":
            return self._install_windows_deps()
        else:
            self.print_warning(f"未知操作系统: {self.system}")
            return True
    
    def _install_macos_deps(self) -> bool:
        """安装macOS依赖"""
        self.print_info("检测到macOS系统")
        
        # 检查是否安装了Homebrew
        try:
            subprocess.run(["brew", "--version"], capture_output=True, check=True)
            self.print_success("Homebrew已安装")
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.print_warning("未检测到Homebrew，某些依赖可能需要手动安装")
            return True
        
        # 安装portaudio（PyAudio的依赖）
        if not self.run_command(["brew", "install", "portaudio"], "安装portaudio"):
            self.print_warning("portaudio安装失败，PyAudio可能无法正常工作")
        
        return True
    
    def _install_linux_deps(self) -> bool:
        """安装Linux依赖"""
        self.print_info("检测到Linux系统")
        
        # 检测包管理器
        package_managers = [
            (["apt-get", "--version"], ["sudo", "apt-get", "update"], ["sudo", "apt-get", "install", "-y", "portaudio19-dev", "python3-pyaudio"]),
            (["yum", "--version"], ["sudo", "yum", "update"], ["sudo", "yum", "install", "-y", "portaudio-devel"]),
            (["pacman", "--version"], ["sudo", "pacman", "-Sy"], ["sudo", "pacman", "-S", "--noconfirm", "portaudio"])
        ]
        
        for check_cmd, update_cmd, install_cmd in package_managers:
            try:
                subprocess.run(check_cmd, capture_output=True, check=True)
                self.print_info(f"使用包管理器: {check_cmd[0]}")
                
                # 更新包列表
                if not self.run_command(update_cmd, "更新包列表"):
                    self.print_warning("包列表更新失败")
                
                # 安装依赖
                if not self.run_command(install_cmd, "安装系统依赖"):
                    self.print_warning("系统依赖安装失败")
                
                return True
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
        
        self.print_warning("未检测到支持的包管理器，请手动安装portaudio开发包")
        return True
    
    def _install_windows_deps(self) -> bool:
        """安装Windows依赖"""
        self.print_info("检测到Windows系统")
        self.print_info("Windows系统通常不需要额外的系统依赖")
        return True
    
    def install_python_packages(self) -> bool:
        """安装Python包"""
        self.print_info("安装Python依赖包...")
        
        packages = [
            "pyaudio",
            "websockets", 
            "asyncio-mqtt"  # 可选，用于更好的异步支持
        ]
        
        success = True
        for package in packages:
            if not self._install_package(package):
                success = False
        
        return success
    
    def _install_package(self, package: str) -> bool:
        """安装单个Python包"""
        # 尝试使用uv安装（如果可用）
        try:
            subprocess.run(["uv", "--version"], capture_output=True, check=True)
            if self.run_command(["uv", "pip", "install", package], f"使用uv安装 {package}"):
                return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
        
        # 回退到pip安装
        return self.run_command([self.python_cmd, "-m", "pip", "install", package], f"使用pip安装 {package}")
    
    def verify_installation(self) -> bool:
        """验证安装"""
        self.print_info("验证安装...")
        
        # 测试导入关键模块
        test_imports = [
            ("pyaudio", "PyAudio音频处理库"),
            ("websockets", "WebSocket通信库"),
            ("asyncio", "异步IO库"),
            ("json", "JSON处理库"),
            ("base64", "Base64编码库"),
            ("threading", "多线程库"),
            ("queue", "队列库")
        ]
        
        failed_imports = []
        for module_name, description in test_imports:
            try:
                __import__(module_name)
                self.print_success(f"{description} - 导入成功")
            except ImportError as e:
                self.print_error(f"{description} - 导入失败: {e}")
                failed_imports.append(module_name)
        
        if failed_imports:
            self.print_error(f"以下模块导入失败: {', '.join(failed_imports)}")
            return False
        
        # 测试PyAudio初始化
        try:
            import pyaudio
            audio = pyaudio.PyAudio()
            device_count = audio.get_device_count()
            audio.terminate()
            self.print_success(f"PyAudio初始化成功，检测到 {device_count} 个音频设备")
        except Exception as e:
            self.print_error(f"PyAudio初始化失败: {e}")
            return False
        
        return True
    
    def show_usage_instructions(self):
        """显示使用说明"""
        print("\n" + "="*60)
        print("🎉 依赖安装完成！")
        print("="*60)
        print("\n📋 使用说明：")
        print("1. 确保后端服务正在运行")
        print("2. 修改测试程序中的服务器地址（如果需要）")
        print("3. 运行测试：python test_microphone_stt.py")
        print("\n🔧 配置选项：")
        print("- 服务器地址：修改 Config.SERVER_HOST 和 Config.SERVER_PORT")
        print("- 录音时长：修改 Config.RECORD_SECONDS")
        print("- 音频质量：修改 Config.SAMPLE_RATE 和 Config.CHUNK_SIZE")
        print("\n⚠️  注意事项：")
        print("- 确保麦克风权限已开启")
        print("- 建议在安静环境中测试")
        print("- 说话要清晰，距离麦克风适中")
        
        if self.system == "darwin":
            print("\n🍎 macOS用户注意：")
            print("- 可能需要在系统偏好设置中授权麦克风权限")
            print("- 首次运行可能会弹出权限请求对话框")
        elif self.system == "linux":
            print("\n🐧 Linux用户注意：")
            print("- 确保用户在audio组中：sudo usermod -a -G audio $USER")
            print("- 可能需要重新登录以使组权限生效")
    
    def run(self):
        """运行安装流程"""
        print("🚀 麦克风测试依赖安装程序")
        print("="*50)
        print(f"Python版本: {sys.version}")
        print(f"操作系统: {platform.system()} {platform.release()}")
        print(f"架构: {platform.machine()}")
        
        try:
            # 1. 安装系统依赖
            if not self.install_system_dependencies():
                self.print_error("系统依赖安装失败")
                return False
            
            # 2. 安装Python包
            if not self.install_python_packages():
                self.print_error("Python包安装失败")
                return False
            
            # 3. 验证安装
            if not self.verify_installation():
                self.print_error("安装验证失败")
                return False
            
            # 4. 显示使用说明
            self.show_usage_instructions()
            
            return True
            
        except KeyboardInterrupt:
            self.print_warning("安装被用户中断")
            return False
        except Exception as e:
            self.print_error(f"安装过程中发生异常: {e}")
            return False


def main():
    """主函数"""
    installer = DependencyInstaller()
    success = installer.run()
    
    if success:
        print("\n✅ 安装成功完成！")
        sys.exit(0)
    else:
        print("\n❌ 安装失败，请检查错误信息")
        sys.exit(1)


if __name__ == "__main__":
    main()