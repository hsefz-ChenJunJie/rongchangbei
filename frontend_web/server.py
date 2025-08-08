#!/usr/bin/env python3
"""
简易HTTP服务器，用于运行荣昶杯项目前端
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

def run_server(port=3000):
    """启动HTTP服务器"""
    
    # 确保在正确的目录中运行
    os.chdir(Path(__file__).parent)
    
    class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
        def end_headers(self):
            # 添加CORS头部，允许跨域请求
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            super().end_headers()
        
        def do_OPTIONS(self):
            # 处理预检请求
            self.send_response(200, "OK")
            self.end_headers()
    
    try:
        with socketserver.TCPServer(("", port), MyHTTPRequestHandler) as httpd:
            print(f"🚀 荣昶杯项目前端服务器启动成功!")
            print(f"📱 访问地址: http://localhost:{port}")
            print(f"📂 服务目录: {os.getcwd()}")
            print("=" * 50)
            print("📋 使用说明:")
            print("1. 确保后端服务器已在 http://localhost:8000 运行")
            print("2. 在浏览器中打开上面的地址")
            print("3. 按照页面步骤体验完整功能循环")
            print("4. 按 Ctrl+C 停止服务器")
            print("=" * 50)
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print(f"\n👋 服务器已停止")
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"❌ 端口 {port} 已被占用，请尝试其他端口")
            print(f"💡 使用命令: python server.py {port + 1}")
        else:
            print(f"❌ 启动失败: {e}")

if __name__ == "__main__":
    port = 3000
    
    # 从命令行参数获取端口号
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("❌ 端口号必须是数字")
            sys.exit(1)
    
    run_server(port)