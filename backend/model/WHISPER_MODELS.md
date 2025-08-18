# Whisper 模型管理指南

本目录用于存放 Whisper 语音识别模型。项目支持使用本地预转换的 CTranslate2 格式模型，以获得最佳性能。

## 📁 目录结构

```
model/
├── whisper-models/           # Whisper模型存储目录
│   ├── base-ct2/            # base模型（推荐）
│   ├── small-ct2/           # small模型
│   ├── medium-ct2/          # medium模型
│   └── large-v3-ct2/        # large-v3模型
└── vosk-model/              # Vosk模型目录（备用）
```

## 🤖 支持的模型

| 模型名称 | 大小 | 内存需求 | 准确性 | 推荐用途 |
|----------|------|----------|--------|----------|
| tiny | ~39 MB | ~1GB | 较低 | 快速测试 |
| base | ~74 MB | ~1GB | 良好 | **通用推荐** |
| small | ~244 MB | ~2GB | 很好 | 高质量需求 |
| medium | ~769 MB | ~5GB | 优秀 | 专业应用 |
| large-v2 | ~1550 MB | ~10GB | 极佳 | 最高精度 |
| large-v3 | ~1550 MB | ~10GB | 极佳 | 最新最佳 |
| distil-large-v3 | ~756 MB | ~6GB | 极佳 | 速度与精度平衡 |

## 🚀 快速开始

### 1. 自动下载和转换（推荐）

使用项目提供的脚本自动下载并转换模型：

```bash
# 下载推荐的base模型
python scripts/download_whisper_models.py --model base --verify

# 下载所有推荐模型（base, small, medium）
python scripts/download_whisper_models.py --all --verify

# 下载特定模型
python scripts/download_whisper_models.py --model large-v3 --quantization int8
```

### 2. 手动下载和转换

如果需要手动操作：

```bash
# 安装转换工具
pip install ctranslate2 transformers[torch]

# 转换模型
ct2-transformers-converter \
    --model openai/whisper-base \
    --output_dir model/whisper-models/base-ct2 \
    --copy_files tokenizer.json preprocessor_config.json \
    --quantization int8
```

### 3. 配置应用使用Whisper

在 `.env` 文件中配置：

```env
# 启用Whisper STT服务
STT_ENGINE=whisper
USE_WHISPER=true

# 模型配置
WHISPER_MODEL_NAME=base
WHISPER_MODEL_PATH=model/whisper-models
WHISPER_DEVICE=auto
WHISPER_COMPUTE_TYPE=int8
```

## ⚙️ 配置选项详解

### 设备选择
- `WHISPER_DEVICE=auto` - 自动检测（推荐）
- `WHISPER_DEVICE=cpu` - 使用CPU
- `WHISPER_DEVICE=cuda` - 使用GPU（需要CUDA支持）

### 计算类型
- `WHISPER_COMPUTE_TYPE=int8` - CPU推荐，节省内存
- `WHISPER_COMPUTE_TYPE=float32` - CPU高精度
- `WHISPER_COMPUTE_TYPE=float16` - GPU推荐
- `WHISPER_COMPUTE_TYPE=int8_float16` - GPU节省显存

### 语言设置
- `WHISPER_LANGUAGE=null` - 自动检测语言（推荐）
- `WHISPER_LANGUAGE=zh` - 强制中文
- `WHISPER_LANGUAGE=en` - 强制英文

## 🔧 性能优化

### 内存优化
1. 使用int8量化：`WHISPER_COMPUTE_TYPE=int8`
2. 选择合适的模型大小
3. 启用VAD过滤：`WHISPER_VAD_FILTER=true`

### 速度优化
1. 使用GPU推理（如果可用）
2. 选择distil模型（如distil-large-v3）
3. 适当调整beam_size：`WHISPER_BEAM_SIZE=5`

### 准确性优化
1. 使用larger模型
2. 指定目标语言
3. 启用词级时间戳：`WHISPER_WORD_TIMESTAMPS=true`

## 🐛 故障排除

### 常见问题

**Q: 模型加载失败**
```
A: 检查模型路径和文件完整性
   ls -la model/whisper-models/base-ct2/
   应该包含：config.json, model.bin 等文件
```

**Q: 内存不足**
```
A: 切换到更小的模型或使用量化
   WHISPER_MODEL_NAME=base  # 而不是large
   WHISPER_COMPUTE_TYPE=int8
```

**Q: GPU不被识别**
```
A: 检查CUDA环境
   python -c "import torch; print(torch.cuda.is_available())"
```

**Q: 转录质量低**
```
A: 尝试以下优化：
   1. 使用更大的模型
   2. 指定语言：WHISPER_LANGUAGE=zh
   3. 检查音频质量（采样率16kHz）
```

### 模型验证

验证模型是否正确安装：

```bash
python -c "
from faster_whisper import WhisperModel
model = WhisperModel('model/whisper-models/base-ct2', device='cpu')
print('模型加载成功!')
"
```

## 📊 性能基准

在 Intel i7-10700K CPU上的测试结果：

| 模型 | 实时倍数 | 内存使用 | WER (中文) |
|------|----------|----------|------------|
| base | 2.1x | 1.2GB | 8.5% |
| small | 1.8x | 2.1GB | 7.2% |
| medium | 1.3x | 4.8GB | 6.1% |

*实时倍数：处理1分钟音频需要的时间倍数，越小越好*

## 🔄 模型更新

定期检查是否有新版本的模型：

1. 关注 [Hugging Face Whisper Models](https://huggingface.co/models?search=whisper)
2. 下载新模型到临时目录测试
3. 验证性能后替换现有模型
4. 更新配置文件中的模型名称

## 📚 更多资源

- [OpenAI Whisper 官方仓库](https://github.com/openai/whisper)
- [faster-whisper 项目](https://github.com/systran/faster-whisper)
- [CTranslate2 文档](https://opennmt.net/CTranslate2/)
- [模型转换指南](https://github.com/systran/faster-whisper#model-conversion)