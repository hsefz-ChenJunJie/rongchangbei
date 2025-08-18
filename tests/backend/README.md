# AI对话应用后端 - 远程API测试套件

完整的远程后端API测试框架，用于验证部署在远程服务器上的AI对话应用后端功能。

## 🚀 快速开始

### 1. 配置测试环境

```bash
# 复制配置文件模板
cp remote_test_config.example.json remote_test_config.json

# 编辑配置文件，设置远程服务器地址
nano remote_test_config.json
```

### 2. 配置示例

```json
{
  "backend_server": {
    "base_url": "http://YOUR_REMOTE_SERVER_IP",
    "port": 8000,
    "health_endpoint": "/",
    "conversation_health_endpoint": "/conversation/health",
    "websocket_endpoint": "/conversation"
  },
  "test_settings": {
    "connection_timeout": 15,
    "response_timeout": 45,
    "max_retries": 3,
    "enable_detailed_logging": true
  }
}
```

### 3. 运行测试

```bash
# 运行所有测试（推荐）
python run_remote_tests.py

# 使用自定义配置文件
python run_remote_tests.py my_config.json

# 单独运行特定测试
python test_websocket_features.py
python test_conversation_features.py
```

## 📁 文件结构

```
tests/backend/
├── README.md                          # 本文档
├── EVENT_LOGGING.md                   # 📝 事件日志系统详细说明
├── remote_test_config.json            # 测试配置文件
├── remote_test_config.example.json    # 配置文件模板
├── remote_test_base.py                 # 测试基础类（含详细事件日志）
├── run_remote_tests.py                 # 综合测试运行器
├── test_websocket_features.py          # WebSocket功能测试
├── test_conversation_features.py       # 完整对话功能测试
└── services/                           # 保留的特殊测试
```

## 📝 新增功能：详细事件日志系统

✨ **v1.2.0 重要更新**：为了更好地调试和分析测试过程，现已新增完整的事件日志记录功能！

### 核心特性
- 🎯 **完整记录**：记录每个发出和接收的WebSocket事件
- ⏱️ **性能分析**：包含时间戳、响应时间、数据大小等元数据
- 🔒 **隐私保护**：自动脱敏音频数据和敏感信息
- 📊 **智能统计**：自动生成事件类型、成功率、性能统计
- 🎨 **可视化展示**：彩色格式化的控制台输出
- 💾 **多格式输出**：支持控制台、JSON文件、结构化日志文件

### 快速配置
```json
{
  "test_settings": {
    "enable_detailed_logging": true,    // 显示详细事件日志
    "enable_file_logging": true,        // 保存到日志文件
    "log_level": "DEBUG",               // 日志级别
    "show_list_items": true,            // 显示列表详细内容
    // ... 其他配置
  }
}
```

### 输出示例
```
┌─ [001] 14:23:45.123 📤 SEND ✅
├─ Event: conversation_start
├─ Session: abc123...
├─ Data:
│  ├─ scenario_description: "项目管理讨论会议"
│  ├─ response_count: 3
├─ Metadata:
│  └─ response_time: 0.001s
└─────────────────────────────────
```

📚 **详细文档**：查看 [EVENT_LOGGING.md](EVENT_LOGGING.md) 了解完整功能和使用指南

## 🧪 测试套件

### 1. WebSocket功能测试 (`test_websocket_features.py`)

- ✅ WebSocket连接建立
- ✅ 对话开始和会话创建
- ✅ 音频消息流程（STT模拟）
- ✅ LLM回答生成
- ✅ 回答数量动态调整
- ✅ 会话恢复功能（如果启用）

### 2. 完整对话功能测试 (`test_conversation_features.py`)

- ✅ 多用户对话模拟
- ✅ 聚焦消息的回答生成
- ✅ 用户修改建议处理
- ✅ 用户选择回答记录
- ✅ 情景补充功能
- ✅ 对话持久性测试

## 📊 测试报告

测试完成后会生成多种格式的报告：

- **综合文本报告**: `comprehensive_remote_test_report_YYYYMMDD_HHMMSS.txt`
- **详细JSON数据**: `comprehensive_remote_test_data_YYYYMMDD_HHMMSS.json`
- **单独测试报告**: `websocket_test_report_YYYYMMDD_HHMMSS.json`

### 🆕 事件日志文件（新增）
- **纯事件日志**: `*_events.json` - 包含完整的事件序列和统计
- **结构化日志**: `event_log_YYYYMMDD_HHMMSS.log` - 可读的时序日志（如启用）
- **事件统计**: 集成在测试报告中，包含性能分析和错误统计

## ⚙️ 配置选项

### 服务器配置 (`backend_server`)

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `base_url` | 远程服务器基础URL | `http://192.168.1.100` |
| `port` | 服务器端口 | `8000` |
| `websocket_endpoint` | WebSocket连接端点 | `/conversation` |

### 测试设置 (`test_settings`)

| 配置项 | 说明 | 推荐值 |
|--------|------|--------|
| `connection_timeout` | 连接超时（秒） | `15` |
| `response_timeout` | 响应超时（秒） | `45` |
| `enable_detailed_logging` | 启用详细事件日志显示 | `true` |
| `enable_file_logging` | 启用事件日志文件记录 | `false` |
| `log_level` | 日志级别（DEBUG/INFO/WARNING/ERROR） | `INFO` |
| `show_list_items` | 显示列表项详细内容 | `false` |
| `test_audio_chunks` | 模拟音频块数量 | `5` |

### 会话恢复测试 (`session_recovery_test`)

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `enable_session_recovery_test` | 启用会话恢复测试 | `true` |
| `disconnect_duration` | 断开持续时间（秒） | `5` |

## 🔧 故障排除

### 常见问题

1. **连接超时**
   ```
   ❌ WebSocket连接超时
   ```
   - 检查服务器地址和端口
   - 确认服务器正在运行
   - 验证网络连接

2. **测试失败**
   ```
   ❌ 对话流程测试失败
   ```
   - 查看详细错误日志
   - 检查服务器日志
   - 验证API配置（如OpenRouter密钥）

3. **会话恢复失败**
   ```
   ⚠️ 会话恢复功能正常（会话已过期）
   ```
   - 这是正常情况，表示会话持久化功能工作正常
   - 可以调整 `disconnect_duration` 进行更严格的测试

### 调试技巧

1. **启用详细日志**
   ```json
   {
     "test_settings": {
       "enable_detailed_logging": true
     }
   }
   ```

2. **增加超时时间**
   ```json
   {
     "test_settings": {
       "connection_timeout": 30,
       "response_timeout": 60
     }
   }
   ```

3. **单步调试**
   ```bash
   # 先测试基础连接
   python test_websocket_features.py
   
   # 再测试完整功能
   python test_conversation_features.py
   ```

## 🎯 成功标准

- **优秀** (100%): 所有测试通过
- **良好** (≥80%): 大部分测试通过，核心功能正常
- **可接受** (≥70%): 基本功能正常，部分高级功能可能有问题
- **需要检查** (<70%): 存在较多问题，需要排查

## 💡 最佳实践

1. **测试前检查**
   - 确认远程服务器正常运行
   - 验证网络连接稳定
   - 检查API密钥和依赖服务

2. **定期测试**
   - 在代码变更后运行测试
   - 定期检查生产环境状态
   - 监控测试成功率趋势

3. **结果分析**
   - 关注失败测试的具体错误
   - 对比历史测试结果
   - 识别性能回归问题

## 📞 技术支持

如果遇到问题：

1. **查看报告**: 检查生成的详细测试报告
2. **检查配置**: 验证配置文件格式和内容
3. **网络诊断**: 使用ping、telnet等工具检查连接
4. **服务器日志**: 查看远程服务器的运行日志
5. **版本兼容**: 确认测试脚本与服务器版本兼容

---

这套测试框架设计为独立、可靠、易于使用的工具，帮助您快速验证远程AI对话应用后端的功能和性能。