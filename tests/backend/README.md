# 荣昶杯AI对话应用后端修复测试

本目录包含针对后端关键问题修复的测试脚本。

## 修复问题

### 问题1：音频流处理失败
- **现象**：前端发送音频流时，后端报错"会话的音频流未开始"
- **根因**：`message_start`事件中没有启动STT音频流处理
- **修复**：在`handle_message_start`方法中添加`stt_service.start_stream_processing()`

### 问题2：response_count_update无效
- **现象**：前端更改response count后，LLM回答数量没有变化
- **根因**：`_call_llm`方法硬编码返回3个建议，忽略count参数
- **修复**：修改`_call_llm`方法签名，添加count参数并在Mock响应中使用

## 测试文件

### 1. test_audio_stream_fix.py
测试音频流处理修复效果：
- 创建会话
- 发送message_start事件
- 发送audio_stream事件（验证无错误）
- 发送message_end事件
- 验证整个音频处理流程

### 2. test_response_count_fix.py
测试response_count_update修复效果：
- 创建会话并添加测试消息
- 手动生成回答（验证初始数量为3）
- 发送response_count_update事件（更新为5）
- 再次手动生成回答（验证数量为5）
- 再次更新数量（验证修复稳定性）

### 3. run_all_tests.py
测试套件运行器：
- 自动启动后端服务（如果未运行）
- 依次运行所有测试
- 生成测试报告
- 清理资源

## 运行测试

### 前置条件
1. 确保已激活正确的mamba环境：
   ```bash
   source ~/.zshrc
   mamba activate rongchang
   ```

2. 安装测试依赖：
   ```bash
   pip install websockets requests
   ```

### 运行方式

#### 方式1：运行完整测试套件（推荐）
```bash
cd /Users/jackchen/Documents/荣昶杯项目/tests/backend
python run_all_tests.py
```

#### 方式2：单独运行测试
```bash
cd /Users/jackchen/Documents/荣昶杯项目/backend

# 先启动后端服务
PYTHONPATH=. python app/main.py &

# 在另一个终端运行测试
cd /Users/jackchen/Documents/荣昶杯项目/tests/backend
python test_audio_stream_fix.py
python test_response_count_fix.py
```

## 测试报告

测试完成后会生成`test_report.txt`文件，包含详细的测试结果和输出。

## 期望结果

如果修复成功，应该看到：

### 音频流测试
```
✅ 对话开始 测试通过
✅ 消息开始 测试通过
✅ 音频流处理 测试通过
✅ 消息结束 测试通过
✅ 对话结束 测试通过
🎉 所有测试通过！音频流处理修复成功！
```

### Response Count测试
```
✅ 设置测试会话 测试通过
✅ 初始手动生成(3个) 测试通过
✅ 更新回答数量为5 测试通过
✅ 更新后手动生成(5个) 测试通过
✅ 再次更新为2个 测试通过
✅ 清理会话 测试通过
🎉 关键测试全部通过！response_count_update修复成功！
```

## 故障排除

### 常见问题

1. **连接服务器失败**
   - 确保后端服务已启动
   - 检查端口8000是否被占用

2. **模块导入错误**
   - 确保已激活rongchang环境
   - 检查PYTHONPATH设置

3. **测试超时**
   - 检查后端服务日志
   - 确认WebSocket连接正常

### 调试方法

1. **查看后端日志**：
   ```bash
   cd /Users/jackchen/Documents/荣昶杯项目/backend
   PYTHONPATH=. python app/main.py
   ```

2. **启用详细日志**：
   在测试文件开头添加：
   ```python
   logging.basicConfig(level=logging.DEBUG)
   ```

3. **手动验证**：
   使用WebSocket客户端工具手动发送事件进行验证。

## 修复代码位置

### 问题1修复
- 文件：`/backend/app/websocket/handlers.py`
- 方法：`handle_message_start`（第226-237行）
- 修改：添加STT流处理启动逻辑

### 问题2修复
- 文件：`/backend/app/services/llm_service.py`
- 方法：`_call_llm`（第264行）和`generate_responses`（第175-180行）
- 修改：添加count参数并在Mock响应中使用