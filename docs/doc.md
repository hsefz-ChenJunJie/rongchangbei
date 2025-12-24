# AI 对话应用前端开发文档

## 概述

本文档为 AI 对话应用的前端开发指南。系统通过 WebSocket 与后端实时通信，支持语音输入、智能对话生成和用户反馈处理。

## 界面设计和状态管理

### 对话页面状态
- **空闲状态**：等待用户开始新消息或手动触发生成回答
- **录制消息中**：显示录音动画和结束消息按钮
- **处理语音转文字中**：显示处理状态，禁用交互
- **生成回答建议中**：手动触发的回答生成，显示加载状态
- 任何时候都可以修改对话情景和建议回答数量。

## 核心功能循环

### 完整对话流程

#### 阶段 1：对话初始化
1. 前端发送对话开始事件到后端（如果是延续之前的情景，需包含历史消息）
2. 界面切换到录音状态

#### 阶段 2：消息录制和处理
1. 用户点击"开始新消息"按钮，输入发送者标识（如自己的姓名）
2. 前端发送消息开始事件到后端
3. 前端持续发送音频流到后端
4. 用户点击"结束消息"按钮
5. 前端发送消息结束事件
6. 后端完成语音转文字，返回消息记录确认（包含消息ID和内容）

#### 阶段 3：手动回答生成和处理
1. 用户选择要关注的消息（可选）
2. 用户提供额外的参考语料（可选）
3. 用户点击"生成回答"按钮
4. 前端发送手动触发生成事件
5. 接收后端返回的多个AI回答建议
6. 在界面展示所有回答选项
7. 用户从中选择满意的回答
8. 将选中回答发送给后端记录为新消息
9. **（可选）接收意见预测**：在发送所选回答后，后端可能会在后台进行分析，并发送一个 `opinion_prediction_response` 事件，其中包含对用户下一步心态的预测。前端可以利用这些信息来更新UI（例如，显示心情标签）。
10. 将选中回答转换为语音播放

#### 阶段 5：对话继续或结束
- 继续对话：返回阶段 2，开始新消息录制
- 结束对话：发送结束事件，清理界面状态

### 重要注意事项

- **会话ID管理**：每个对话都有唯一ID，前端需要在所有事件中携带此ID
- **消息ID管理**：每条消息都有唯一ID，用于引用和聚焦消息
- **状态管理**：对话状态包括："idle"、"recording_message"、"processing_stt"、"generating_response"
- **音频处理**：音频数据需要 base64 编码后发送
- **消息流程**：必须先发送消息开始事件再发送音频流
- **修改建议即时处理**：用户发送修改建议后立即触发新的回答生成
- **选择回答记录**：用户选择的LLM回答必须发送给后端记录

## WebSocket 事件通信

### 连接地址
使用 ws 协议，端口为 8000

### 事件字段规范说明
所有WebSocket事件都遵循必需和可选字段规范：
- **[必需]** 字段：必须包含，不能为空或null
- **[可选]** 字段：可以省略，或设置为空值
- 字段验证失败将返回错误事件
- session_id在对话开始事件中不需要，其他事件均为必需

### 前端发送的事件

#### 对话开始
```json
{
  "type": "conversation_start", // [必需]
  "data": {
    "scenario_description": "对话情景描述文本", // [可选] 
    "response_count": 3, // [必需] 1-5之间的整数
    "history_messages": [ // [可选] 之前会话中记录的所有消息
      {
        "message_id": "msg_0000001", // [必需] 前端提供的历史消息唯一ID
        "sender": "用户姓名", // [必需] 消息发送者标识
        "content": "消息内容" // [必需] 消息内容
      }
    ],
    "user_profile": { // [可选] 用户档案（mock 存储）
      "name": "测试用户",
      "age": 28,
      "gender": "female",
      "relations": ["self"],
      "personalities": ["理性", "耐心"],
      "preferences": ["简洁表达"],
      "taboos": ["过度承诺"],
      "common_topics": ["项目进展", "技术分享"]
    },
    "target_profile": { // [可选] 当前对话对象档案（mock 存储）
      "name": "对话机器人",
      "age": 2,
      "gender": "neutral",
      "relations": ["assistant"],
      "personalities": ["友好"],
      "preferences": ["明确问题"],
      "taboos": ["含糊其辞"],
      "common_topics": ["任务澄清", "需求拆解"]
    }
  }
}
```

#### 消息开始
```json
{
  "type": "message_start", // [必需]
  "data": {
    "session_id": "会话唯一ID", // [必需] 会话创建后获得
    "sender": "消息发送者标识" // [必需] 消息发送者（如用户姓名、角色等）
  }
}
```

#### 音频流
```json
{
  "type": "audio_stream", // [必需]
  "data": {
    "session_id": "会话唯一ID", // [必需] 会话创建后获得
    "audio_chunk": "base64编码的音频数据" // [必需] 音频数据块
  }
}
```

#### 消息结束
```json
{
  "type": "message_end", // [必需]
  "data": {
    "session_id": "会话ID" // [必需] 目标会话标识
  }
}
```

#### 手动触发生成回答
```json
{
  "type": "manual_generate", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "focused_message_ids": ["msg_001", "msg_003"] // [可选] 用户选择聚焦的消息ID数组
  }
}
```

#### 用户选择回答
```json
{
  "type": "user_selected_response", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "selected_content": "用户选择的回答内容", // [必需] 用户选择的LLM回答
    "sender": "用户标识" // [必需] 消息发送者（即用户自己）
  }
}
```

#### 对话结束
```json
{
  "type": "conversation_end", // [必需]
  "data": {
    "session_id": "会话ID" // [必需]
  }
}
```

#### 会话恢复
```json
{
  "type": "session_resume", // [必需]
  "data": {
    "session_id": "要恢复的会话ID" // [必需] 之前保存的会话ID
  }
}
```

#### 用户反馈
- 修改建议：
```json
{
  "type": "user_modification", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "modification": "修改建议文本" // [必需] 对AI回复的修改意见
  }
}
```
- 补充情景：
```json
{
  "type": "scenario_supplement", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "supplement": "补充情景描述" // [必需] 补充的对话情景信息
  }
}
```
- 修改回答数量：
```json
{
  "type": "response_count_update", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "response_count": 4 // [必需] 新的建议回答数量，1-5之间的整数
  }
}
```

### 后端返回的事件

#### 会话创建确认
```json
{
  "type": "session_created", // [必需]
  "data": {
    "session_id": "生成的唯一会话ID" // [必需] 后续所有操作需要此ID
  }
}
```

#### 消息记录确认
```json
{
  "type": "message_recorded", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "message_id": "消息唯一ID", // [必需] 分配给消息的ID
    "message_content": "消息内容" // [可选] 消息内容，仅录制消息时包含
  }
}
```

#### 档案回传 (profile_archive)
```json
{
  "type": "profile_archive", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "user_profile": { // [可选] conversation_start 中存储的用户档案
      "name": "测试用户",
      "age": 28,
      "gender": "female",
      "relations": ["self"],
      "personalities": ["理性", "耐心"],
      "preferences": ["简洁表达"],
      "taboos": ["过度承诺"],
      "common_topics": ["项目进展", "技术分享"]
    },
    "target_profile": { // [可选] conversation_start 中存储的对话对象档案
      "name": "对话机器人",
      "age": 2,
      "gender": "neutral",
      "relations": ["assistant"],
      "personalities": ["友好"],
      "preferences": ["明确问题"],
      "taboos": ["含糊其辞"],
      "common_topics": ["任务澄清", "需求拆解"]
    }
  }
}
```
> 触发：收到 `conversation_end` 后立即返回（mock），连接保持开启。

#### 会话恢复成功
```json
{
  "type": "session_restored", // [必需]
  "data": {
    "session_id": "恢复的会话ID", // [必需]
    "status": "会话状态", // [必需] 如 "idle", "processing" 等
    "message_count": 5, // [必需] 会话中的消息数量
    "scenario_description": "对话情景描述", // [可选] 对话情景
    "response_count": 3, // [必需] 回答生成数量
    "has_modifications": false, // [必需] 是否有修改建议
    "restored_at": "2025-08-18T10:30:45.123Z" // [必需] 恢复时间
  }
}
```

#### AI回答建议
```json
{
  "type": "llm_response", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "suggestions": ["建议回答1", "建议回答2", "建议回答3"], // [必需] 回答建议数组
    "request_id": "请求唯一标识" // [可选] 用于请求追踪
  }
}
```

#### 意见预测响应 (opinion_prediction_response)
```json
{
  "type": "opinion_prediction_response", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "prediction": { // [必需]
      "tendency": "合作 | 对抗 | 中立 | 探索 | 安抚", // [必需] 预测的意见倾向
      "mood": "积极 | 消极 | 平静 | 好奇 | 困惑", // [必需] 预测的心情
      "tone": "正式 | 随意 | 坚定 | 委婉 | 幽默" // [必需] 预测的语气
    },
    "request_id": "请求唯一标识" // [可选] 用于请求追踪
  }
}
```

#### 状态更新
```json
{
  "type": "status_update", // [必需]
  "data": {
    "session_id": "会话ID", // [必需]
    "status": "idle|recording_message|processing_stt|generating_response", // [必需] 会话状态
    "message": "状态描述" // [可选] 状态的文字描述
  }
}
```
**状态说明：**
- `idle`：空闲状态，等待新消息或手动触发
- `recording_message`：正在录制消息中
- `processing_stt`：处理语音转文字中
- `generating_response`：手动触发的回答生成中

#### 错误信息
```json
{
  "type": "error", // [必需]
  "data": {
    "session_id": "会话ID", // [可选] 会话相关错误才包含
    "error_code": "错误代码", // [必需] 标准化错误代码
    "message": "错误描述", // [必需] 用户友好的错误描述
    "details": "详细错误信息" // [可选] 调试用的详细信息
  }
}
```

## 音频处理要求

### 录制参数
- 采样率：16000 Hz
- 声道：单声道
- 格式：建议 webm/opus
- 发送间隔：100ms

### 处理流程（累积模式）
1. 申请麦克风权限
2. 创建 MediaRecorder 实例
3. 定期收集音频数据块
4. 转换为 base64 格式
5. 通过 WebSocket 持续发送（累积在后端）
6. 消息结束后，后端一次性处理所有音频

### 断连恢复机制
- 后端会自动保存录音过程中的累积音频数据
- 重连后可以继续在原有基础上录音
- 最终处理时会合并断连前后的所有音频

### 语音播放
自行选择本地 tts 完成播放。

## 错误处理

### 重连机制
WebSocket 连接断开时，自动尝试重连（最多 5 次，间隔递增）。

## 会话恢复功能

### 功能概述
当WebSocket连接因为网络问题或前端崩溃等非正常原因断开时，后端会自动保存会话状态到本地文件。前端重新连接后，可以使用会话ID恢复之前的对话状态。

### 使用场景
- 网络不稳定导致的连接中断
- 前端应用崩溃或被意外关闭
- 用户主动刷新页面或切换应用
- 移动设备息屏或切换到后台

### 实现机制
1. **自动保存**：非正常断连时，后端自动将会话状态保存到 `./sessions/` 目录
2. **文件存储**：使用JSON格式存储会话数据，包含消息历史、状态、配置等
3. **音频保护**：录音过程中断连时，自动保存累积的音频数据
4. **定期清理**：过期会话（默认24小时）自动清理
5. **状态恢复**：恢复会话的完整状态，包括消息、修改建议、用户意见和累积音频

### 配置选项
```bash
# 环境变量配置
SESSION_PERSISTENCE_ENABLED=true      # 是否启用会话持久化
SESSION_PERSISTENCE_DIR=./sessions    # 会话存储目录
SESSION_MAX_PERSISTENCE_HOURS=24      # 最大持久化时间(小时)
SESSION_CLEANUP_INTERVAL_MINUTES=60   # 清理间隔(分钟)
```

### 前端实现指南

#### 保存会话ID
```javascript
// 在收到 session_created 事件时保存会话ID
ws.onmessage = function(event) {
  const response = JSON.parse(event.data);
  
  if (response.type === 'session_created') {
    const sessionId = response.data.session_id;
    // 保存到 localStorage，以便页面刷新后恢复
    localStorage.setItem('currentSessionId', sessionId);
  }
};
```

#### 检测并恢复会话
```javascript
// 页面加载时检查是否有未完成的会话
window.onload = function() {
  const savedSessionId = localStorage.getItem('currentSessionId');
  
  if (savedSessionId) {
    // 连接WebSocket并尝试恢复会话
    const ws = new WebSocket('ws://localhost:8000/conversation');
    
    ws.onopen = function() {
      // 发送会话恢复请求
      ws.send(JSON.stringify({
        type: "session_resume",
        data: {
          session_id: savedSessionId
        }
      }));
    };
    
    ws.onmessage = function(event) {
      const response = JSON.parse(event.data);
      
      if (response.type === 'session_restored') {
        // 会话恢复成功，更新UI状态
        const sessionData = response.data;
        console.log('会话恢复成功:', sessionData);
        
        // 根据返回的会话数据恢复UI状态
        updateUIFromSession(sessionData);
        
      } else if (response.type === 'error') {
        // 会话恢复失败，清理保存的会话ID
        localStorage.removeItem('currentSessionId');
        console.log('会话恢复失败:', response.data.message);
      }
    };
  }
};
```

#### 清理会话状态
```javascript
// 正常结束对话时清理保存的会话ID
function endConversation(sessionId) {
  // 发送对话结束事件
  ws.send(JSON.stringify({
    type: "conversation_end",
    data: {
      session_id: sessionId
    }
  }));
  
  // 清理本地保存的会话ID
  localStorage.removeItem('currentSessionId');
}
```

## 前端集成技术指南

### 连接地址
- **开发环境**：`ws://localhost:8000/conversation`
- **生产环境**：`wss://your-domain.com/conversation`

### 健康检查端点
- **后端总健康检查**：`GET http://localhost:8000/`
  - 用途：简单的进程存活检查，快速响应
  - 适用于：负载均衡器 health check、监控系统

- **对话服务健康检查**：`GET http://localhost:8000/conversation/health`
  - 用途：深度检查对话相关服务状态（STT、LLM、会话管理等）
  - 适用于：服务诊断、故障排查

### WebSocket 连接示例
```javascript
// 建立WebSocket连接
const ws = new WebSocket('ws://localhost:8000/conversation');

ws.onopen = function() {
  console.log('WebSocket连接已建立');
  
  // 检查是否有需要恢复的会话
  const savedSessionId = localStorage.getItem('currentSessionId');
  
  if (savedSessionId) {
    // 尝试恢复会话
    ws.send(JSON.stringify({
      type: "session_resume",
      data: { session_id: savedSessionId }
    }));
  } else {
    // 开始新对话
    ws.send(JSON.stringify({
      type: "conversation_start",
      data: {
        scenario_description: "商务会议讨论", // 可选
        response_count: 3 // 必需，1-5之间的整数
      }
    }));
  }
};

ws.onmessage = function(event) {
  const response = JSON.parse(event.data);
  console.log('收到消息:', response);
  
  switch(response.type) {
    case 'session_created':
      const sessionId = response.data.session_id;
      localStorage.setItem('currentSessionId', sessionId);
      console.log('会话创建成功，ID:', sessionId);
      break;
      
    case 'session_restored':
      console.log('会话恢复成功:', response.data);
      // 根据恢复的会话数据更新UI
      break;
      
    case 'message_recorded':
      console.log('消息记录成功，ID:', response.data.message_id);
      break;
      
    case 'llm_response':
      console.log('AI回答建议:', response.data.suggestions);
      break;
      
    case 'error':
      console.error('错误:', response.data.message);
      if (response.data.error_code === 'SESSION_NOT_FOUND') {
        // 会话不存在，清理本地存储
        localStorage.removeItem('currentSessionId');
      }
      break;
  }
};

ws.onerror = function(error) {
  console.error('WebSocket错误:', error);
};

ws.onclose = function(event) {
  console.log('WebSocket连接已关闭:', event.code, event.reason);
  // 非正常关闭时，保留会话ID以便后续恢复
};
```

### 错误码处理
- `SESSION_NOT_FOUND`：会话不存在或已过期，清理本地存储
- `INVALID_EVENT_DATA`：事件数据格式错误，检查发送的数据
- `INTERNAL_ERROR`：服务器内部错误，稍后重试
