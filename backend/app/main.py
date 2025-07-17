from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sse_starlette.sse import EventSourceResponse
from pydantic import BaseModel
from typing import List, Optional
import io
import os
import tempfile
import time
import logging
import json
import asyncio

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 全局模型实例
stt_model = None
stt_processor = None
stt_tokenizer = None
tts_model = None
llm_model = None

def load_stt_model():
    """
    加载STT模型，在应用启动时调用
    支持transformers格式和原生whisper格式
    """
    global stt_model, stt_processor, stt_tokenizer
    try:
        # 模型路径配置
        model_path = os.path.join(os.path.dirname(__file__), "..", "models", "stt")
        
        # 检查是否存在transformers格式的模型
        if os.path.exists(model_path) and os.path.isfile(os.path.join(model_path, "config.json")):
            try:
                # 尝试加载transformers格式的whisper模型
                from transformers import WhisperProcessor, WhisperForConditionalGeneration
                
                logger.info(f"正在加载本地transformers格式的STT模型: {model_path}")
                stt_processor = WhisperProcessor.from_pretrained(model_path)
                stt_model = WhisperForConditionalGeneration.from_pretrained(model_path)
                stt_tokenizer = stt_processor.tokenizer
                
                logger.info("Transformers格式STT模型加载成功")
                return True
                
            except Exception as e:
                logger.warning(f"Transformers格式模型加载失败: {str(e)}, 尝试原生whisper格式")
        
        # 回退到原生whisper格式
        import whisper
        
        # 尝试加载本地whisper模型文件
        local_model_files = []
        if os.path.exists(model_path):
            for file in os.listdir(model_path):
                if file.endswith(('.pt', '.pth', '.bin')):
                    local_model_files.append(os.path.join(model_path, file))
        
        if local_model_files:
            # 加载本地whisper模型
            model_file = local_model_files[0]
            logger.info(f"正在加载本地whisper格式STT模型: {model_file}")
            stt_model = whisper.load_model(model_file)
        else:
            # 如果没有本地模型，使用whisper默认模型
            logger.info("未找到本地STT模型，使用whisper默认base模型")
            stt_model = whisper.load_model("base")
            
        logger.info("原生whisper格式STT模型加载成功")
        return True
        
    except ImportError as e:
        logger.error(f"必要的库未安装: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"STT模型加载失败: {str(e)}")
        return False


def load_tts_model():
    """
    加载TTS模型，在应用启动时调用
    使用Coqui TTS库从本地路径加载模型
    """
    global tts_model
    try:
        # 导入TTS库
        from TTS.api import TTS
        
        # TTS模型路径配置
        tts_model_path = os.path.join(os.path.dirname(__file__), "..", "models", "tts")
        config_path = os.path.join(tts_model_path, "config.json")
        
        # 检查是否存在本地TTS模型
        if os.path.exists(tts_model_path) and os.listdir(tts_model_path):
            # 尝试从本地路径加载模型
            logger.info(f"正在从本地路径加载TTS模型: {tts_model_path}")
            
            # 列出所有文件便于调试
            all_files = os.listdir(tts_model_path)
            logger.info(f"TTS模型目录中的所有文件: {all_files}")
            
            # 检查模型文件
            config_files = [f for f in all_files if f.endswith('.json') and 'config' in f.lower()]
            # 排除speakers文件，只选择真正的模型文件
            model_files = [f for f in all_files 
                          if f.endswith(('.pth', '.pt', '.ckpt')) and 'speaker' not in f.lower()]
            
            logger.info(f"找到配置文件: {config_files}")
            logger.info(f"找到模型文件: {model_files}")
            
            # 尝试多种加载方式
            tts_model = None
            
            # 方法1：直接使用目录路径加载
            try:
                logger.info(f"尝试方法1：使用目录路径加载TTS模型: {tts_model_path}")
                tts_model = TTS(model_path=tts_model_path, config_path=config_path,)
                logger.info("TTS模型加载成功（使用目录路径）")
            except Exception as e:
                logger.warning(f"方法1失败: {e}")
                
            # 方法2：如果方法1失败且有配置文件，尝试使用model_type
            if tts_model is None and config_files:
                try:
                    logger.info("尝试方法2：使用model_type='tts'参数")
                    tts_model = TTS(model_path=tts_model_path, model_type="tts")
                    logger.info("TTS模型加载成功（使用model_type参数）")
                except Exception as e:
                    logger.warning(f"方法2失败: {e}")
            
            # 方法3：如果前面都失败，尝试远程XTTS模型
            if tts_model is None:
                try:
                    logger.info("尝试方法3：使用远程XTTS模型")
                    tts_model = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2")
                    logger.info("TTS模型加载成功（使用远程XTTS模型）")
                except Exception as e:
                    logger.warning(f"方法3失败: {e}")
            
            # 如果所有方法都失败，抛出异常
            if tts_model is None:
                raise Exception("所有TTS模型加载方法都失败")
                
        else:
            # 如果没有本地模型，使用默认的中文TTS模型
            logger.info("未找到本地TTS模型，使用默认中文TTS模型")
            try:
                tts_model = TTS(model_name="tts_models/zh-CN/baker/vits")
                logger.info("TTS模型加载成功（使用默认中文模型）")
            except Exception as e:
                logger.warning(f"默认中文模型加载失败: {e}")
                # 最后的回退：使用最基础的英文模型
                logger.info("尝试使用基础英文TTS模型")
                tts_model = TTS(model_name="tts_models/en/ljspeech/tacotron2-DDC")
                logger.info("TTS模型加载成功（使用基础英文模型）")
            
        logger.info("TTS模型加载成功")
        return True
        
    except ImportError:
        logger.error("TTS库未安装，请运行: pip install TTS")
        return False
    except Exception as e:
        logger.error(f"TTS模型加载失败: {str(e)}")
        return False


def load_llm_model():
    """
    加载LLM模型，在应用启动时调用
    使用ctransformers库从本地路径加载GGUF格式的模型
    """
    global llm_model
    try:
        # 导入ctransformers
        from ctransformers import AutoModelForCausalLM
        
        # LLM模型路径配置
        llm_model_path = os.path.join(os.path.dirname(__file__), "..", "models", "llm", "Qwen3-4B-Q4_0.gguf")
        
        # 检查模型文件是否存在
        if not os.path.exists(llm_model_path):
            logger.error(f"LLM模型文件不存在: {llm_model_path}")
            return False
        
        # 检查模型文件大小
        file_size = os.path.getsize(llm_model_path) / (1024**3)  # GB
        logger.info(f"LLM模型文件大小: {file_size:.2f}GB")
        
        logger.info(f"正在加载LLM模型: {llm_model_path}")
        
        # 智能配置硬件参数
        import psutil
        
        # 获取系统信息
        cpu_count = psutil.cpu_count(logical=False)  # 物理核心数
        memory_gb = psutil.virtual_memory().total / (1024**3)  # 总内存GB
        
        # 智能配置参数
        context_length = 4096  # 上下文窗口大小
        threads = min(cpu_count, 8)  # 线程数不超过8
        
        # GPU配置（ctransformers支持GPU加速）
        gpu = False
        try:
            import torch
            if torch.cuda.is_available():
                gpu = True
                logger.info("检测到GPU，启用GPU加速")
        except ImportError:
            logger.info("未检测到PyTorch或CUDA，使用CPU模式")
        
        # 根据内存调整上下文窗口
        if memory_gb < 8:
            context_length = 2048  # 内存不足8GB时减少上下文窗口
            logger.info(f"内存较小({memory_gb:.1f}GB)，调整上下文窗口为{context_length}")
        
        logger.info(f"硬件配置: CPU核心={cpu_count}, 内存={memory_gb:.1f}GB, 线程={threads}, 上下文={context_length}, GPU={gpu}")
        
        # 加载模型
        try:
            llm_model = AutoModelForCausalLM.from_pretrained(
                llm_model_path,
                model_type="qwen",  # 指定模型类型
                context_length=context_length,
                threads=threads,
                gpu_layers=-1 if gpu else 0,  # -1表示全部层使用GPU，0表示CPU
                stream=True,  # 启用流式输出
                local_files_only=True  # 只使用本地文件
            )
        except Exception as e:
            error_msg = str(e)
            logger.error(f"LLM模型初始化失败: {error_msg}")
            
            # 尝试使用更保守的参数
            logger.info("尝试使用更保守的参数重新加载LLM模型")
            try:
                llm_model = AutoModelForCausalLM.from_pretrained(
                    llm_model_path,
                    model_type="qwen",
                    context_length=2048,  # 减少上下文窗口
                    threads=2,  # 减少线程数
                    gpu_layers=0,  # 禁用GPU
                    stream=True,
                    local_files_only=True
                )
            except Exception as e2:
                logger.error(f"保守参数也失败: {str(e2)}")
                # 尝试自动检测模型类型
                logger.info("尝试自动检测模型类型")
                try:
                    llm_model = AutoModelForCausalLM.from_pretrained(
                        llm_model_path,
                        context_length=2048,
                        threads=2,
                        gpu_layers=0,
                        stream=True,
                        local_files_only=True
                    )
                except Exception as e3:
                    logger.error(f"自动检测也失败: {str(e3)}")
                    return False
        
        logger.info("LLM模型加载成功")
        return True
        
    except ImportError:
        logger.error("ctransformers库未安装，请运行: pip install ctransformers")
        return False
    except Exception as e:
        logger.error(f"LLM模型加载失败: {str(e)}")
        return False


def load_system_prompt() -> str:
    """
    从llm.md文件加载系统提示词
    """
    try:
        system_prompt_path = os.path.join(os.path.dirname(__file__), "..", "llm.md")
        with open(system_prompt_path, 'r', encoding='utf-8') as f:
            return f.read().strip()
    except Exception as e:
        logger.error(f"加载系统提示词失败: {e}")
        # 回退到默认系统提示词
        return "你是一个顶级的、富有同情心和高情商的沟通助手，专门为一个有语言障碍的用户提供支持。\n你的核心任务是：在用户需要时，根据对方的谈话内容和用户的基本意图，从多种角度考虑问题，生成多种风格的、高质量的回答建议，帮助用户流畅、自信地进行交流。\n**你的行为准则:**\n1.  **多样性**: 永远提供多种不同语气和风格的建议（例如：简洁直接、礼貌委婉、幽默友好、提出反问等）。\n2.  **同理心**: 你的回答建议应始终保持积极、尊重和支持的态度。"


def build_structured_prompt(request: 'GenerateSuggestionsRequest') -> str:
    """
    根据请求内容构建结构化的用户Prompt
    """
    prompt_parts = []
    
    # 处理对话情景
    if request.scenario_context and request.scenario_context.strip():
        prompt_parts.append(f"对话情景：{request.scenario_context.strip()}")
    
    # 处理目标对话内容
    if request.target_dialogue and request.target_dialogue.strip():
        prompt_parts.append(f"对话内容：{request.target_dialogue.strip()}")
    
    # 处理用户意见
    if request.user_opinion and request.user_opinion.strip():
        prompt_parts.append(f"用户意见：{request.user_opinion.strip()}")
    
    # 处理修改建议
    if request.modification_suggestion and len(request.modification_suggestion) > 0:
        modifications = [mod.strip() for mod in request.modification_suggestion if mod.strip()]
        if modifications:
            prompt_parts.append("严格遵循以下修改意见：")
            prompt_parts.append(' '.join(modifications))
    
    # 生成要求
    suggestion_count = request.suggestion_count or 3
    prompt_parts.append(f"请生成{suggestion_count}条高质量的回答建议。")
    
    # 输出格式要求（因为ctransformers不支持JSON Schema，需要在提示词中指定）
    prompt_parts.append("请严格按照以下JSON格式输出，不要添加任何额外的文字说明：")
    prompt_parts.append(json.dumps({
        "suggestions": [
            {
                "id": 1,
                "content": "建议内容1",
                "confidence": 0.85
            },
            {
                "id": 2,
                "content": "建议内容2",
                "confidence": 0.80
            }
        ]
    }, ensure_ascii=False, indent=2))
    
    return '\n\n'.join(prompt_parts)


def get_json_schema() -> dict:
    """
    获取JSON Schema用于强制格式化输出
    """
    return {
        "type": "object",
        "properties": {
            "suggestions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "content": {"type": "string"},
                        "confidence": {"type": "number", "minimum": 0, "maximum": 1}
                    },
                    "required": ["id", "content", "confidence"]
                }
            }
        },
        "required": ["suggestions"]
    }


def apply_qwen2_chat_template(system_prompt: str, user_prompt: str) -> str:
    """
    应用Qwen2模型的聊天模板，分离系统提示词和用户提示词
    """
    # Qwen2的聊天模板格式
    chat_template = f"""<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
{user_prompt}<|im_end|>
<|im_start|>assistant
"""
    
    return chat_template


app = FastAPI(title="荣昶杯项目 API", version="1.0.0")

# 应用启动事件
@app.on_event("startup")
async def startup_event():
    """应用启动时执行的事件"""
    logger.info("正在启动荣昶杯项目 API...")
    
    # 加载STT模型
    stt_success = load_stt_model()
    if not stt_success:
        logger.warning("STT模型加载失败，STT功能将不可用")
    
    # 加载TTS模型
    tts_success = load_tts_model()
    if not tts_success:
        logger.warning("TTS模型加载失败，TTS功能将不可用")
    
    # 加载LLM模型
    llm_success = load_llm_model()
    if not llm_success:
        logger.warning("LLM模型加载失败，LLM功能将不可用")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def health_check():
    return {"status": "healthy", "message": "荣昶杯项目 API is running"}


# STT 数据模型
class STTResponse(BaseModel):
    text: str
    confidence: Optional[float] = None
    processing_time: Optional[float] = None


# TTS 数据模型
class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = "default"
    speed: Optional[float] = 1.0


# LLM 数据模型
class GenerateSuggestionsRequest(BaseModel):
    scenario_context: Optional[str] = None
    user_opinion: Optional[str] = None
    target_dialogue: Optional[str] = None
    modification_suggestion: Optional[List[str]] = None
    suggestion_count: Optional[int] = 3


class Suggestion(BaseModel):
    id: int
    content: str
    confidence: Optional[float] = None


class GenerateSuggestionsResponse(BaseModel):
    suggestions: List[Suggestion]
    processing_time: Optional[float] = None


# API 端点定义
@app.post("/api/stt", response_model=STTResponse)
async def speech_to_text(audio: UploadFile = File(...)):
    """
    语音转文字 API
    
    接收音频文件并返回转写的文本
    支持transformers格式和原生whisper格式的模型
    """
    global stt_model, stt_processor, stt_tokenizer
    
    # 检查模型是否已加载
    if stt_model is None:
        raise HTTPException(status_code=503, detail="STT模型未加载，服务不可用")
    
    # 记录开始时间
    start_time = time.time()
    
    # 临时文件路径
    temp_audio_path = None
    
    try:
        # 验证文件类型
        if not audio.content_type or not any(mime in audio.content_type for mime in ['audio/', 'video/']):
            raise HTTPException(status_code=400, detail="请上传音频文件")
        
        # 读取上传的音频数据
        audio_data = await audio.read()
        
        # 创建临时文件保存音频
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_audio_path = temp_file.name
            temp_file.write(audio_data)
        
        # 根据模型类型进行语音识别
        if stt_processor is not None:
            # 使用transformers格式的模型
            transcribed_text, confidence = await transcribe_with_transformers(temp_audio_path)
        else:
            # 使用原生whisper格式的模型
            transcribed_text, confidence = await transcribe_with_whisper(temp_audio_path)
        
        # 计算处理时间
        processing_time = time.time() - start_time
        
        logger.info(f"STT处理完成: {transcribed_text[:50]}... (耗时: {processing_time:.2f}s)")
        
        return STTResponse(
            text=transcribed_text,
            confidence=confidence,
            processing_time=processing_time
        )
        
    except Exception as e:
        logger.error(f"STT处理失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"语音识别失败: {str(e)}")
    
    finally:
        # 清理临时文件
        if temp_audio_path and os.path.exists(temp_audio_path):
            try:
                os.unlink(temp_audio_path)
                logger.debug(f"已清理临时文件: {temp_audio_path}")
            except Exception as e:
                logger.warning(f"清理临时文件失败: {e}")


async def transcribe_with_transformers(audio_path: str):
    """
    使用transformers格式的whisper模型进行语音识别
    """
    import torch
    import librosa
    
    # 加载音频文件
    audio_array, sampling_rate = librosa.load(audio_path, sr=16000)
    
    # 预处理音频
    input_features = stt_processor(
        audio_array, 
        sampling_rate=sampling_rate, 
        return_tensors="pt"
    ).input_features
    
    # 设置中文语言token
    forced_decoder_ids = stt_processor.get_decoder_prompt_ids(language="chinese", task="transcribe")
    
    # 生成转写结果
    with torch.no_grad():
        predicted_ids = stt_model.generate(
            input_features,
            forced_decoder_ids=forced_decoder_ids,
            max_length=448,
            num_beams=5,
            early_stopping=True
        )
    
    # 解码结果
    transcribed_text = stt_processor.batch_decode(predicted_ids, skip_special_tokens=True)[0]
    
    # 简单的置信度估算（transformers模型没有直接的置信度）
    confidence = 0.85  # 固定值，实际项目中可以基于模型输出计算
    
    return transcribed_text.strip(), confidence


async def transcribe_with_whisper(audio_path: str):
    """
    使用原生whisper模型进行语音识别
    """
    # 使用whisper进行语音识别
    result = stt_model.transcribe(
        audio_path,
        language="zh",  # 指定中文
        task="transcribe"
    )
    
    # 提取识别结果
    transcribed_text = result.get("text", "").strip()
    
    # 计算置信度（基于segments计算平均值）
    confidence = 0.0
    if "segments" in result and result["segments"]:
        confidences = []
        for segment in result["segments"]:
            if "avg_logprob" in segment:
                # 将对数概率转换为置信度（近似）
                conf = min(1.0, max(0.0, (segment["avg_logprob"] + 1.0)))
                confidences.append(conf)
        if confidences:
            confidence = sum(confidences) / len(confidences)
    
    return transcribed_text, confidence


@app.post("/api/tts")
async def text_to_speech(request: TTSRequest):
    """
    文字转语音 API
    
    接收文本并返回音频流
    使用Coqui TTS模型进行语音合成
    """
    global tts_model
    
    # 检查模型是否已加载
    if tts_model is None:
        raise HTTPException(status_code=503, detail="TTS模型未加载，服务不可用")
    
    # 验证输入
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="请提供要合成的文本内容")
    
    # 记录开始时间
    start_time = time.time()
    
    # 临时文件路径
    temp_audio_path = None
    
    try:
        # 创建临时文件保存音频
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_audio_path = temp_file.name
        
        # 使用TTS模型进行语音合成
        logger.info(f"正在合成语音: {request.text[:50]}...")
        
        # 调用TTS模型生成音频
        tts_model.tts_to_file(
            text=request.text,
            file_path=temp_audio_path,
            speed=request.speed if request.speed else 1.0
        )
        
        # 计算处理时间
        processing_time = time.time() - start_time
        logger.info(f"TTS处理完成，耗时: {processing_time:.2f}s")
        
        # 读取生成的音频文件
        def generate_audio():
            try:
                with open(temp_audio_path, "rb") as audio_file:
                    while True:
                        chunk = audio_file.read(8192)  # 8KB chunks
                        if not chunk:
                            break
                        yield chunk
            except Exception as e:
                logger.error(f"读取音频文件失败: {e}")
                yield b""
            finally:
                # 在生成器结束时清理临时文件
                if temp_audio_path and os.path.exists(temp_audio_path):
                    try:
                        os.unlink(temp_audio_path)
                        logger.debug(f"已清理临时音频文件: {temp_audio_path}")
                    except Exception as e:
                        logger.warning(f"清理临时音频文件失败: {e}")
        
        # 返回音频流
        return StreamingResponse(
            generate_audio(),
            media_type="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=tts_output.wav",
                "X-Processing-Time": str(processing_time)
            }
        )
        
    except Exception as e:
        logger.error(f"TTS处理失败: {str(e)}")
        # 确保在出错时也清理临时文件
        if temp_audio_path and os.path.exists(temp_audio_path):
            try:
                os.unlink(temp_audio_path)
            except:
                pass
        raise HTTPException(status_code=500, detail=f"语音合成失败: {str(e)}")


@app.post("/api/generate_suggestions")
async def generate_suggestions(request: GenerateSuggestionsRequest):
    """
    生成回答建议 API（流式响应）
    
    根据上下文信息生成多个回答建议，使用Server-Sent Events实现流式响应
    """
    global llm_model
    
    # 检查模型是否已加载
    if llm_model is None:
        raise HTTPException(status_code=503, detail="LLM模型未加载，服务不可用")
    
    # 加载系统提示词
    system_prompt = load_system_prompt()
    
    # 构建结构化的用户Prompt
    user_prompt = build_structured_prompt(request)
    
    # 应用Qwen2聊天模板
    formatted_prompt = apply_qwen2_chat_template(system_prompt, user_prompt)
    
    logger.info(f"开始生成建议，prompt长度: {len(formatted_prompt)}")
    
    # 生成器函数，用于流式响应
    async def generate_stream():
        try:
            start_time = time.time()
            
            # 使用ctransformers进行流式生成
            # ctransformers的API稍有不同，需要适配
            accumulated_text = ""
            
            # ctransformers流式生成
            for token in llm_model(
                formatted_prompt,
                max_new_tokens=1024,
                temperature=0.7,
                top_p=0.9,
                stop=["<|im_end|>", "<|endoftext|>"],
                stream=True,
                reset=False  # 不重置对话历史
            ):
                accumulated_text += token
                
                # 发送token数据
                yield {
                    "event": "token",
                    "data": json.dumps({
                        "token": token,
                        "accumulated": accumulated_text
                    }, ensure_ascii=False)
                }
                
                # 添加小延迟以模拟真实的流式效果
                await asyncio.sleep(0.01)
            
            # 计算处理时间
            processing_time = time.time() - start_time
            
            # 解析JSON结果（使用JSON Mode后应该更可靠）
            try:
                # 使用JSON Mode后，输出应该已经是有效的JSON
                json_text = accumulated_text.strip()
                
                # 尝试解析JSON
                result = json.loads(json_text)
                
                # 验证JSON结构符合Schema
                if 'suggestions' in result and isinstance(result['suggestions'], list):
                    suggestions = result['suggestions']
                    # 验证每个建议的结构
                    for suggestion in suggestions:
                        if not all(key in suggestion for key in ['id', 'content', 'confidence']):
                            raise ValueError("建议格式不完整")
                else:
                    raise ValueError("JSON结构不符合预期")
                
            except (json.JSONDecodeError, ValueError) as e:
                logger.warning(f"JSON解析失败: {e}, 原始文本: {accumulated_text[:100]}...")
                # 如果JSON Mode失败，创建包含原始文本的响应
                suggestions = [
                    {
                        "id": 1,
                        "content": accumulated_text[:200] + "..." if len(accumulated_text) > 200 else accumulated_text,
                        "confidence": 0.75
                    }
                ]
            
            # 发送最终结果
            yield {
                "event": "complete",
                "data": json.dumps({
                    "suggestions": suggestions,
                    "processing_time": processing_time,
                    "raw_text": accumulated_text
                }, ensure_ascii=False)
            }
            
        except Exception as e:
            logger.error(f"LLM生成失败: {str(e)}")
            yield {
                "event": "error",
                "data": json.dumps({
                    "error": f"生成失败: {str(e)}"
                }, ensure_ascii=False)
            }
    
    # 返回Server-Sent Events响应
    return EventSourceResponse(generate_stream())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)