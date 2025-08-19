# 更新日志

## [v1.4.0] - 2025-08-19

### 重大性能优化
- **架构重构**: STT语音识别服务完全重构为**非阻塞式架构**，解决了渐进式识别导致主线程阻塞的性能问题。
- **移除事件**: 根据用户反馈，彻底移除了 `partial_transcription_update` 事件，以减少不必要的网络拥堵。

### 技术实现
- **非阻塞处理**: 当音频缓冲区满后，转录任务将通过 `asyncio.create_task` 在后台运行，主线程可继续接收新的音频数据，实现接收和识别的并行处理。
- **顺序一致性**: 通过为每个会话引入 `asyncio.Lock`，确保了并行的后台转录任务能按正确的顺序将其结果追加到累积文本中。
- **静默累积**: 所有识别出的文本都在后端静默累积，仅在收到 `message_end` 事件后，通过 `message_recorded` 事件一次性返回完整结果。
- **资源管理**: `get_final_transcription` 方法现在会等待所有后台任务完成后再进行最终整合，保证了数据的完整性。

### API 变更
- **移除事件**: `partial_transcription_update` (后端→前端) 事件已从协议中完全移除。

### 影响评估
- **性能**: ✅ 根本上解决了STT处理阻塞的问题，大幅提升了系统在高频音频流下的吞吐量和响应速度。
- **兼容性**: ✅ 对前端而言，除了不再收到 `partial_transcription_update` 事件外，其他接口和事件保持不变。

---

## [v1.3.1] - 2025-08-19

### API 改进
- **撤回变更**: 恢复 `message_recorded` 事件中的 `message_content` 字段，但实现差异化逻辑
- **优化**: 录制消息时包含消息内容，用户选择回答时不包含消息内容

### 详细变更
- **录制消息场景**: `message_recorded` 事件包含 `message_content` 字段，内容为STT转录结果
- **用户选择回答场景**: `message_recorded` 事件不包含 `message_content` 字段，前端自行管理内容
- **技术实现**: 使用 `Optional[str]` 类型实现可选字段，保持向后兼容性

### 事件格式示例

**录制消息后**:
```json
{
  "type": "message_recorded",
  "data": {
    "session_id": "session_123",
    "message_id": "msg_001", 
    "message_content": "这是语音转录的内容"
  }
}
```

**用户选择回答后**:
```json
{
  "type": "message_recorded",
  "data": {
    "session_id": "session_123",
    "message_id": "msg_002"
    // 注意：没有 message_content 字段
  }
}
```

### 文档更新
- 同步更新 `prompt.md`、`docs/doc.md`、`ai_development_prompt.md` 中的事件格式说明
- 更新字段规范，明确可选字段的使用场景

### 向后兼容性
- ✅ 完全向后兼容，`message_content` 字段为可选字段
- ✅ 不影响不使用该字段的现有前端实现
- ✅ 为需要消息内容的前端提供了便利

---

## [v1.3.0] - 2025-08-18

### 重大功能更新
- **新增**: 会话恢复功能 - 支持非正常断连时的会话持久化和恢复
- **重大变更**: 简化消息确认事件格式 - 移除 `message_recorded` 事件中的 `content` 和 `sender` 字段
- **新增**: 长时间WebSocket连接持久性测试工具

### 会话恢复功能
- **会话持久化**: 非正常断连时自动保存会话到本地文件系统
- **会话恢复**: 前端可通过 `session_resume` 事件恢复中断的会话
- **自动清理**: 定期清理过期的持久化会话文件
- **配置选项**: 支持启用/禁用、存储目录、持久化时长等配置

### API 变更
- **简化事件**: `message_recorded` 事件现仅包含 `session_id` 和 `message_id` 字段
- **新增事件**: 
  - `session_resume` (前端→后端): 请求恢复指定会话
  - `session_restored` (后端→前端): 确认会话恢复成功
- **配置新增**: 会话持久化相关配置项

### 技术实现
- 新增 `SessionPersistenceManager` 类：基于JSON文件的会话存储
- 新增 `PeriodicCleanupTask` 类：定期清理过期会话
- 扩展 WebSocket 处理器：支持会话保存和恢复逻辑
- 集成到应用生命周期：启动时初始化，关闭时清理

### 测试支持
- **新增**: 90秒 WebSocket 持久性测试 `test_websocket_persistence.py`
- **性能监控**: 内存、CPU使用率跟踪和详细报告生成
- **异常检测**: 自动检测WebSocket异常断线和重连

### 文档更新
- 同步更新所有相关API文档
- 更新事件格式说明
- 添加会话恢复功能使用指南

### 配置选项
```bash
# 新增配置项
SESSION_PERSISTENCE_ENABLED=true      # 是否启用会话持久化
SESSION_PERSISTENCE_DIR=./sessions    # 会话存储目录  
SESSION_MAX_PERSISTENCE_HOURS=24      # 最大持久化时间(小时)
SESSION_CLEANUP_INTERVAL_MINUTES=60   # 清理间隔(分钟)
```

### 向后兼容性
- ✅ 会话恢复功能为可选功能，不影响现有API
- ⚠️ `message_recorded` 事件格式简化，前端需适配（移除content/sender字段的依赖）
- ✅ 所有现有配置和功能保持兼容

---

## [v1.2.1] - 2025-08-15

### 关键Bug修复
- **修复**: 音频流处理失败问题 - 前端发送audio_stream事件时后端不再报错"会话的音频流未开始"
- **修复**: response_count_update事件无效问题 - LLM回答数量现在能正确响应前端的数量设置
- **改进**: 增强STT音频流生命周期管理，在message_start事件中自动启动音频流处理
- **改进**: 优化LLM Mock服务的count参数处理逻辑，支持动态回答数量

### 技术实现
- 修改`WebSocketHandler.handle_message_start()`方法，添加STT音频流启动逻辑
- 修改`LLMService._call_llm()`方法签名，添加count参数支持
- 增加STT服务启动失败的错误处理和日志记录
- 同步更新OpenRouterLLMService的方法签名以保持一致性

### 测试体系建设
- **新增**: 完整的后端测试套件 `/tests/backend/`
- **新增**: 音频流处理专项测试 `test_audio_stream_fix.py`
- **新增**: response_count更新专项测试 `test_response_count_fix.py` 
- **新增**: 自动化测试运行器 `run_all_tests.py`
- **新增**: 详细的测试文档和使用说明

### 验证结果
- ✅ 音频流处理测试通过：完整的message_start → audio_stream → message_end流程无错误
- ✅ response_count测试通过：3个→5个→2个建议数量变化验证成功
- ✅ 系统稳定性：修复提升了核心功能的稳定性，无向后兼容性问题

### 影响评估
- **兼容性**: ✅ 完全向后兼容，无API变更
- **性能**: ✅ 无负面性能影响
- **稳定性**: ✅ 显著提升音频和LLM功能稳定性

---

## [v1.2.0] - 2025-08-14

### 历史消息ID处理优化
- **API变更**: `conversation_start`事件的历史消息现在需要前端提供`message_id`字段
- **改进**: 避免网络冗余，前端负责维护历史消息ID，后端直接使用前端提供的ID
- **字段变更**: `HistoryMessage`模型新增必需的`message_id`字段
- **向后兼容**: 现有没有历史消息的对话不受影响

### 技术实现
- 修改`HistoryMessage`模型，要求前端提供消息ID
- 更新对话开始处理逻辑，直接使用前端提供的消息ID
- 避免后端重复发送历史消息内容，减少网络传输

### 文档更新  
- 更新前后端文档以反映新的历史消息格式要求
- 明确前端需要在恢复对话时提供历史消息ID

---

## [v1.1.0] - 2025-08-13

### 端点架构优化
- **BREAKING CHANGE**: 将 WebSocket 端点从 `/ws` 更改为 `/conversation`
- **BREAKING CHANGE**: 将根健康检查从 `/api/health` 更改为 `/`
- **新增**: `/conversation/health` 对话服务专用健康检查端点
- **移除**: `/health/ready` 冗余端点

### 技术改进
- WebSocket 客户端ID改为服务器端自动生成
- 优化健康检查响应格式，提供更详细的服务状态信息
- 改进端点语义化命名，便于系统扩展

### 文档更新
- 更新 README.md 前端集成示例
- 更新所有部署配置文件的健康检查URL
- 完善 API 端点文档和使用说明
- 添加详细的响应示例

### 向后兼容性
⚠️ **注意**: 此版本包含破坏性变更，前端需要更新连接地址：
- WebSocket: `ws://localhost:8000/ws` → `ws://localhost:8000/conversation`
- 健康检查: `GET /api/health` → `GET /`

---

## [v1.0.0] - 2025-08-13

### 初始版本
- ✅ 基于 FastAPI + WebSocket 的事件驱动架构
- ✅ 完整的对话服务功能（STT、LLM、会话管理）
- ✅ 支持 Vosk 语音识别和 OpenRouter LLM 集成
- ✅ Docker 容器化部署支持
- ✅ 详细的配置管理和文档

### 核心功能
- WebSocket 实时通信
- 语音转文字 (STT)
- AI 对话生成 (LLM)  
- 会话生命周期管理
- 并发请求管理
- 用户反馈处理

### 部署支持
- 开发环境部署
- Docker 容器化部署
- 生产环境配置优化
- 完整的配置文档和故障排除指南