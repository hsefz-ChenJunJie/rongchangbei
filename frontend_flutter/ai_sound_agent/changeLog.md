## Change log

# Date: 2025-11-21 , patch=1
- 更新接口实现以匹配文档要求：
    - 音频流格式改为opus编码
    - 移除profile_prompt字段
    - 添加会话恢复和错误处理

# Date: 2025-11-21 , patch=2
- 修复LoadingStep.loading枚举值不存在的问题，改为使用sendingStartRequest
- 完善session_restored消息处理逻辑，支持完整的会话恢复功能
- 添加error消息处理，增强错误处理机制