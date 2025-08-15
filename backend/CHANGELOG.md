# 更新日志

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