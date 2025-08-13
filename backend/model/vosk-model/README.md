# Vosk 语音识别模型目录

此目录用于存放 Vosk STT (Speech-to-Text) 模型文件。

## 快速设置

### 方法1：下载中文模型（推荐）
```bash
cd backend/model/vosk-model
wget https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
unzip vosk-model-cn-0.22.zip
mv vosk-model-cn-0.22/* .
rm -rf vosk-model-cn-0.22 vosk-model-cn-0.22.zip
```

### 方法2：下载小型英文模型
```bash
cd backend/model/vosk-model
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
mv vosk-model-small-en-us-0.15/* .
rm -rf vosk-model-small-en-us-0.15 vosk-model-small-en-us-0.15.zip
```

## 模型下载地址

- **中文模型**：https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip (~500MB)
- **小型英文模型**：https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip (~50MB)
- **更多模型**：https://alphacephei.com/vosk/models

## 正确的目录结构

下载并解压后，此目录应包含：
```
vosk-model/
├── README.md (本文件)
├── .gitkeep
├── am/          # 声学模型
├── conf/        # 配置文件
├── graph/       # 解码图
└── ivector/     # i-vector提取器
```

## 使用说明

1. **开发环境**：应用会自动检测此目录中的模型文件
2. **Mock模式**：如果没有模型文件，应用将使用Mock STT服务
3. **配置项**：通过环境变量 `VOSK_MODEL_PATH` 可以指定模型路径

## 注意事项

- 模型文件较大，已被添加到 `.gitignore` 中，不会上传到代码仓库
- 首次部署时需要手动下载模型文件
- Docker 部署时可以通过卷挂载预下载的模型目录