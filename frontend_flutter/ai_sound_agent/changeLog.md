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

# Date: 2025-11-21 , patch=3
- 整合对话人档案页面与对话人管理页面：
    - 在对话人管理页面每个对话人卡片中添加档案编辑按钮
    - 点击档案编辑按钮可直接进入档案编辑页面
    - 在档案编辑页面添加示例文本生成按钮
    - 示例文本生成功能可生成包含姓名、城市、星座、爱好等信息的示例文本

# Date: 2025-11-21 , patch=4
- 重构档案编辑页面界面设计：
    - 主界面显示大文本框，实时展示整合后的自然语言描述
    - 表单填写时实时更新文本框内容（如："名字叫小陈，年龄为37岁，不喜欢谈论疾病史"）
    - 添加"显示/隐藏编辑表单"切换按钮，简化界面
    - 发送到后端的信息为自然语言文本，非JSON格式
    - 最终文本直接展示给用户，并标注"最终发送给AI"

# Date: 2025-11-22 , patch=1

1. 修改对话启动逻辑
    在 _establishWebSocketConnection 方法中，我修改了场景描述的构建逻辑：

    - 当存在当前聊天对象时，会在原场景描述后附加聊天对象的详细信息
    - 格式为： 原对话情景描述文本\n\n你现在的聊天对象：[详细信息]
2. 添加详细信息构建方法
    新增了 _buildPartnerInfoString 方法，用于构建聊天对象的详细信息字符串，包含：

    - 基本信息 ：姓名、关系类型
    - 年龄性别 ：如果有设置则显示
    - 性格特点 ：列出所有性格标签
    - 禁忌话题 ：如果有设置则显示
    - 共同经历 ：如果有设置则显示

# Date: 2025-11-22 , patch=2
添加"我想想……"填充消息功能：
- 在用户发送消息到LLM后，有30%概率触发"我想想……"填充消息
- 填充消息会在1-3秒延迟后显示，模拟AI思考时间
- 消息以系统身份显示，使用灰色样式区分于正常对话
- 仅在会话连接正常时才会显示填充消息

# Date: 2025-11-22 , patch=3
- Fixed RenderFlex overflow issue in main_processing.dart by reducing vertical padding from 8px to 6px in top action bar and profile selector containers

# Date: 2025-11-22 , patch=4
- 优化聊天界面进入逻辑：
    - 从主页进入聊天界面时，不再强制选择对话人profile
    - 从对话人管理页面进入时，自动使用对应对话人的profile
    - 避免因用户再次选择导致无法及时发送并开启对话
    - 当存在当前聊天对象时，会在原场景描述后附加其详细信息

# Date: 2025-11-22 , patch=5
- 删除主聊天界面顶部的对话人档案选择器：
    - 移除main_processing.dart中的档案选择下拉框
    - 保持对话人档案功能在后台正常工作
    - 简化界面，避免用户重复选择档案
    - 从对话人管理页面进入时仍自动使用对应档案

# Date: 2025-12-22 , patch=1
根据错误日志，我发现了关键问题：`AudioRecorder`在使用Opus编码和流模式时，需要提供输出路径，但流模式不支持Opus编码。让我查看当前的录音配置并修复这个问题：

## 问题修复总结

我已经成功修复了音频录制错误。问题的根本原因是：

### 错误原因
`AudioRecorder`在使用流模式(`startStream`)时不支持Opus编码，导致抛出异常：
```
E/AudioRecorder(12779): Path not provided. Stream is not supported.
E/AudioRecorder(12779): java.lang.IllegalArgumentException: Path not provided. Stream is not supported.
```

### 修复方案

1. **修改音频编码格式**：将编码格式从`AudioEncoder.opus`改为`AudioEncoder.pcm16bits`
2. **更新音频参数计算**：根据PCM16编码格式重新计算音频时长
   - PCM16: 16位 = 2字节，16000Hz采样率，单声道
   - 时长 = 字节数 / (2字节/样本 × 16000样本/秒 × 1声道) = 字节数 / 32000
3. **调整分块大小**：将分块大小从16000字节改为32000字节（对应1秒的PCM16音频数据）
4. **更新音频格式标识**：将格式从'opus'改为'pcm16'

### 关键修改点

1. **录音配置**：
```dart
final stream = await _audioRecorder.startStream(const RecordConfig(
  encoder: AudioEncoder.pcm16bits, // 改为PCM16编码
  sampleRate: 16000,
  numChannels: 1,
));
```

2. **音频时长计算**：
```dart
// PCM16编码的时长计算
double duration = audioData.length / 32000.0; // 32000字节/秒
```

3. **音频元数据**：
```json
{
  "format": "pcm16",
  "sample_rate": 16000,
  "channels": 1,
  "duration": 1.0
}
```

这样修改后，音频录制功能应该能正常工作，并且后端能够正确接收到音频时长信息。