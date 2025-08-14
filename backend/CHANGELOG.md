# 更新日志

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