# 荣昶杯项目后端 API

## 项目描述
这是荣昶杯项目的后端 API，实现了语音转文字(STT)、文字转语音(TTS)和回答建议生成(LLM)等核心功能。

## 环境要求
- Python 3.11
- Mamba/Conda 环境管理器

## 安装和运行

### 1. 激活虚拟环境并安装依赖
```bash
mamba activate rongchang
pip install -r requirements.txt
```

### 2. 启动服务器
```bash
./start_server.sh
```

或者直接运行：
```bash
python main.py
```

### 3. 查看 API 文档
服务器启动后，可以通过以下地址查看 API 文档：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API 端点

### 1. 健康检查
- **GET** `/`
- 返回服务器状态信息

### 2. 语音转文字 (STT)
- **POST** `/api/stt`
- 接收音频文件，返回转写的文本
- 输入：音频文件 (multipart/form-data)
- 输出：`{"text": "转写结果", "confidence": 0.95, "processing_time": 1.2}`

### 3. 文字转语音 (TTS)
- **POST** `/api/tts`
- 接收文本，返回音频流
- 输入：`{"text": "要转换的文本", "voice": "default", "speed": 1.0}`
- 输出：音频流 (audio/wav)

### 4. 生成回答建议 (LLM)
- **POST** `/api/generate_suggestions`
- 根据上下文信息生成多个回答建议
- 输入：
  ```json
  {
    "scenario_context": "对话情景",
    "user_opinion": "用户意见",
    "target_dialogue": "目标对话",
    "modification_suggestion": ["修改建议1", "修改建议2"],
    "suggestion_count": 3
  }
  ```
- 输出：
  ```json
  {
    "suggestions": [
      {"id": 1, "content": "建议1", "confidence": 0.8},
      {"id": 2, "content": "建议2", "confidence": 0.7}
    ],
    "processing_time": 0.5
  }
  ```

## 开发状态

### 阶段一：框架与API定义 ✅
- [x] 项目初始化
- [x] 定义STT接口
- [x] 定义TTS接口
- [x] 定义LLM核心接口
- [x] 生成API文档

### 阶段二：核心逻辑实现 (待完成)
- [ ] 实现STT功能
- [ ] 实现TTS功能
- [ ] 实现LLM核心功能

## 注意事项
- 当前所有接口都返回占位符数据
- 需要在阶段二中实现实际的模型调用逻辑
- 所有接口都已配置CORS，允许跨域访问