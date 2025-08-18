# 事件日志系统说明

## 概述

为了更好地调试和分析测试过程中的WebSocket通信，我们为远程测试系统增加了详细的事件日志功能。该系统能够记录每一个发出和接收的事件，包括详细的元数据和统计信息。

## 主要功能

### 📝 详细事件记录
- **发送事件**：记录每个向服务器发送的WebSocket事件
- **接收事件**：记录每个从服务器接收的WebSocket事件
- **HTTP请求**：记录健康检查等HTTP请求
- **连接事件**：记录WebSocket连接建立过程

### ⏱️ 时间和性能统计
- 事件时间戳（精确到毫秒）
- 响应时间测量
- 超时设置记录
- 消息大小统计

### 🔒 安全和隐私
- 音频数据自动脱敏（只显示长度）
- 敏感字段（密钥、令牌等）自动隐藏
- 支持配置敏感信息列表

### 📊 统计分析
- 事件总数和分类统计
- 成功/失败事件统计
- 平均响应时间计算
- 会话级事件统计

## 配置选项

在 `remote_test_config.json` 的 `test_settings` 部分配置：

```json
{
  "test_settings": {
    "enable_detailed_logging": true,    // 启用详细日志显示
    "enable_file_logging": true,        // 启用文件日志记录
    "log_level": "DEBUG",               // 日志级别: DEBUG/INFO/WARNING/ERROR
    "show_list_items": true,            // 显示列表项详细内容
    // ... 其他配置
  }
}
```

### 配置说明

- **enable_detailed_logging**: 控制是否在控制台显示详细的事件日志
- **enable_file_logging**: 是否将日志保存到文件
- **log_level**: 日志记录级别，影响日志详细程度
- **show_list_items**: 是否展示列表类型字段的详细内容

## 日志输出格式

### 控制台输出
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

### 日志文件格式
```
14:23:45.123 [WebSocketFeatureTester_events] INFO: ✅ [SEND] conversation_start (session: abc123...) [count=3] (time: 0.001s)
```

## 输出文件

测试完成后会生成以下文件：

1. **`*_test_report_*.json`** - 完整测试报告，包含事件日志
2. **`*_events.json`** - 纯事件日志数据
3. **`event_log_*.log`** - 结构化日志文件（如果启用文件日志）

## 事件类型

### 连接相关
- `websocket_connect` - WebSocket连接建立
- `http_get/post` - HTTP请求

### WebSocket事件
- **发送事件 (SEND)**:
  - `conversation_start` - 开始对话
  - `message_start` - 开始消息
  - `audio_stream` - 音频流
  - `message_end` - 结束消息
  - `manual_generate` - 手动生成
  - `user_modification` - 用户修改
  - `response_count_update` - 更新回答数量
  - `conversation_end` - 结束对话

- **接收事件 (RECV)**:
  - `session_created` - 会话创建确认
  - `message_recorded` - 消息记录确认
  - `opinion_suggestions` - 意见建议
  - `llm_response` - LLM回答
  - `status_update` - 状态更新
  - `error` - 错误事件

## 使用示例

### 基本使用
```python
from remote_test_base import RemoteTestBase

# 创建测试实例（会自动加载日志配置）
tester = RemoteTestBase("remote_test_config.json")

# 运行测试（事件会自动记录）
websocket = await tester.connect_websocket()
await tester.send_websocket_event(websocket, "conversation_start", {...})
event = await tester.receive_websocket_event(websocket, "session_created")

# 显示事件统计
tester.print_event_summary()

# 保存报告（包含事件日志）
tester.save_test_report("my_test_report.json")
```

### 高级配置
```python
# 清空事件日志（新测试开始时）
tester.clear_event_log()

# 获取事件统计
stats = tester._get_event_statistics()
print(f"总事件数: {stats['total_events']}")
print(f"平均响应时间: {stats['average_response_time']}秒")
```

## 调试技巧

### 问题诊断
1. **连接问题**: 查看 `websocket_connect` 事件的错误信息
2. **超时问题**: 检查 `response_time` 和 `timeout` 元数据
3. **数据问题**: 查看事件数据内容和 `message_size`
4. **序列问题**: 使用事件序列号追踪事件顺序

### 性能分析
- 通过 `average_response_time` 分析整体性能
- 查看单个事件的 `response_time` 找出瓶颈
- 统计不同事件类型的数量分布

### 错误追踪
- 查看失败事件的 `error` 元数据
- 检查事件序列找出失败模式
- 分析 `type_mismatch` 检测协议问题

## 最佳实践

1. **生产环境**: 设置 `log_level` 为 `INFO` 或 `WARNING`
2. **调试阶段**: 使用 `DEBUG` 级别和 `show_list_items: true`
3. **性能测试**: 关闭详细日志显示以避免影响测试结果
4. **长期运行**: 启用文件日志记录便于后续分析

## 故障排除

### 常见问题

**Q: 日志显示过多信息**
A: 设置 `enable_detailed_logging: false` 或调整 `log_level`

**Q: 文件日志没有生成**
A: 检查 `enable_file_logging` 设置和文件写入权限

**Q: 音频数据显示为 `<audio_data_length:xxx>`**
A: 这是正常的脱敏处理，保护敏感数据

**Q: 事件统计显示异常**
A: 检查是否在测试中途调用了 `clear_event_log()`

---

## 版本历史

- **v1.0.0** - 初始版本，基本事件记录功能
- **v1.1.0** - 增加详细统计和文件日志
- **v1.2.0** - 增加敏感信息脱敏和性能优化