from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
import io
import os
import tempfile
import time
import logging
import json
import asyncio
import traceback
from openai import AsyncOpenAI

# 配置日志
# 设置为 DEBUG 级别以查看详细调试信息，设置为 INFO 以查看一般信息
LOG_LEVEL = logging.DEBUG  # 可以改为 logging.INFO 来减少日志输出

logging.basicConfig(
    level=LOG_LEVEL,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 为了避免aiohttp的调试日志过多，单独设置其日志级别
logging.getLogger('aiohttp').setLevel(logging.WARNING)
logging.getLogger('asyncio').setLevel(logging.WARNING)

# ==================== 模型加载开关配置 ====================
# 控制是否加载各种模型
MODEL_LOAD_CONFIG = {
    "load_stt": True,   # 是否加载STT模型
    "load_tts": True,   # 是否加载TTS模型
    "load_llm": True    # 是否加载LLM模型
}

# ==================== 远程API服务商配置 ====================
# 请在这里填写您的远程API服务商信息
REMOTE_API_CONFIG = {
    # 示例配置 - 请根据您的服务商修改以下信息
    "api_url": "http://192.168.0.11:1234/v1",  # 替换为您的API地址
    "api_key": "unused",  # 替换为您的API密钥
    "model_name": "qwen/qwen3-8b",  # 替换为您要使用的模型名称
    "temperature": 0.7,
    "top_p": 0.9,
    "stream": False,
    
    # 常见服务商预设配置（取消注释并填写对应的API Key）
    # OpenAI配置
    # "api_url": "https://api.openai.com/v1/chat/completions",
    # "api_key": "sk-your-openai-key",
    # "model_name": "gpt-3.5-turbo",
    
    # 智谱AI配置
    # "api_url": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
    # "api_key": "your-zhipu-key",
    # "model_name": "glm-4",
    
    # 百度千帆配置
    # "api_url": "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions",
    # "api_key": "your-baidu-key",
    # "model_name": "ernie-bot-turbo",
    
    # 阿里云通义千问配置
    # "api_url": "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation",
    # "api_key": "your-aliyun-key",
    # "model_name": "qwen-turbo",
}

# 全局模型实例
stt_model = None
stt_processor = None
stt_tokenizer = None
tts_model = None
llm_model = None
use_remote_llm = False  # 标记是否使用远程LLM

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
        
        # 直接使用模型名称加载TTS模型
        logger.info("使用模型名称加载TTS模型")
        
        # 使用XTTS v2多语言模型，按照官方方式加载
        logger.info("正在加载XTTS v2多语言模型...")
        
        # 检测GPU可用性
        gpu_available = False
        try:
            import torch
            if torch.cuda.is_available():
                gpu_available = True
                logger.info("检测到GPU，启用GPU加速")
        except ImportError:
            logger.info("未检测到PyTorch或CUDA，使用CPU模式")
        
        tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=gpu_available)
        logger.info(f"TTS模型加载成功（使用XTTS v2模型，GPU: {gpu_available}）")
            
        logger.info("TTS模型加载成功")
        return True
        
    except ImportError:
        logger.error("TTS库未安装，请运行: pip install TTS")
        return False
    except Exception as e:
        logger.error(f"TTS模型加载失败: {str(e)}")
        return False


def filter_special_tokens(text: str) -> str:
    """
    过滤掉模型输出中的特殊标记
    """
    # 定义需要过滤的特殊标记
    special_tokens = [
        '<think>',
        '</think>',
        '<|im_start|>',
        '<|im_end|>',
        '<|system|>',
        '<|user|>',
        '<|assistant|>',
        '<|end|>',
        '<thinking>',
        '</thinking>',
        '<thought>',
        '</thought>',
        '<reflection>',
        '</reflection>'
    ]
    
    # 过滤掉特殊标记
    filtered_text = text
    
    # 首先移除思考内容块（包含开始和结束标记之间的所有内容）
    import re
    thinking_patterns = [
        r'<thinking>.*?</thinking>',
        r'<think>.*?</think>',
        r'<thought>.*?</thought>',
        r'<reflection>.*?</reflection>',
        # 处理可能的换行情况
        r'<thinking>\s*\n.*?\n\s*</thinking>',
        r'<think>\s*\n.*?\n\s*</think>',
    ]
    
    for pattern in thinking_patterns:
        filtered_text = re.sub(pattern, '', filtered_text, flags=re.DOTALL | re.IGNORECASE)
    
    # 然后过滤剩余的特殊标记
    for token in special_tokens:
        filtered_text = filtered_text.replace(token, '')
    
    # 清理多余的空行和空格
    lines = filtered_text.split('\n')
    cleaned_lines = []
    for line in lines:
        cleaned_line = line.strip()
        if cleaned_line:  # 只保留非空行
            cleaned_lines.append(cleaned_line)
    
    return '\n'.join(cleaned_lines)


def extract_json_from_text(text: str) -> str:
    """
    从包含思考内容的文本中提取JSON
    支持多种JSON格式和位置
    """
    import re
    
    logger.debug(f"🔍 开始从文本中提取JSON，原始长度: {len(text)} 字符")
    
    # 首先尝试提取markdown代码块中的JSON
    json_patterns = [
        # ```json ... ```
        r'```json\s*\n(.*?)\n```',
        r'```json\s*(.*?)```',
        # ```JSON ... ```
        r'```JSON\s*\n(.*?)\n```',
        r'```JSON\s*(.*?)```',
        # ``` ... ``` (如果包含"suggestions")
        r'```\s*\n(.*?suggestions.*?)\n```',
        r'```\s*(.*?suggestions.*?)```',
    ]
    
    for pattern in json_patterns:
        matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)
        for match in matches:
            json_candidate = match.strip()
            if json_candidate and ('suggestions' in json_candidate.lower() or '{' in json_candidate):
                logger.info(f"📝 在代码块中找到JSON候选: {json_candidate[:100]}...")
                if validate_json_candidate(json_candidate):
                    return json_candidate
    
    # 寻找JSON对象开始和结束标记
    brace_patterns = [
        # 寻找以 { 开始, } 结束的完整JSON对象
        r'\{[^{}]*"suggestions"[^{}]*\[[^\]]*\][^{}]*\}',
        # 更复杂的嵌套JSON
        r'\{(?:[^{}]|\{[^{}]*\})*"suggestions"(?:[^{}]|\{[^{}]*\})*\}',
    ]
    
    for pattern in brace_patterns:
        matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)
        for match in matches:
            json_candidate = match.strip()
            logger.info(f"📝 在文本中找到JSON候选: {json_candidate[:100]}...")
            if validate_json_candidate(json_candidate):
                return json_candidate
    
    # 尝试寻找JSON开始位置并提取到结尾
    json_start_patterns = [
        r'(\{[^{}]*"suggestions".*)',  # 从{开始包含suggestions的部分
        r'.*?(\{.*?"suggestions".*?\}.*?)(?:\n|$)',  # 包含suggestions的行
    ]
    
    for pattern in json_start_patterns:
        matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)
        for match in matches:
            json_candidate = match.strip()
            # 尝试平衡大括号
            json_candidate = balance_braces(json_candidate)
            if json_candidate and validate_json_candidate(json_candidate):
                logger.info(f"📝 提取并平衡大括号后的JSON: {json_candidate[:100]}...")
                return json_candidate
    
    # 最后尝试：寻找任何看起来像JSON的内容
    lines = text.split('\n')
    for i, line in enumerate(lines):
        line = line.strip()
        if line.startswith('{') and ('suggestions' in line.lower() or 'content' in line.lower()):
            # 尝试从这行开始提取多行JSON
            json_candidate = '\n'.join(lines[i:])
            json_candidate = balance_braces(json_candidate)
            if json_candidate and validate_json_candidate(json_candidate):
                logger.info(f"📝 从第{i+1}行开始提取JSON: {json_candidate[:100]}...")
                return json_candidate
    
    logger.warning("⚠️ 未能从文本中提取有效的JSON")
    return text.strip()


def balance_braces(text: str) -> str:
    """
    平衡大括号，确保JSON格式正确
    """
    if not text.strip():
        return text
    
    # 找到第一个 {
    start_idx = text.find('{')
    if start_idx == -1:
        return text
    
    brace_count = 0
    end_idx = start_idx
    
    for i in range(start_idx, len(text)):
        if text[i] == '{':
            brace_count += 1
        elif text[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                end_idx = i
                break
    
    if brace_count == 0:
        return text[start_idx:end_idx + 1]
    else:
        # 如果大括号不平衡，尝试修复
        return text[start_idx:] + '}' * brace_count


def validate_json_candidate(json_text: str) -> bool:
    """
    验证JSON候选文本是否有效
    """
    try:
        parsed = json.loads(json_text)
        # 检查是否包含我们需要的结构
        if isinstance(parsed, dict) and 'suggestions' in parsed:
            suggestions = parsed['suggestions']
            if isinstance(suggestions, list) and len(suggestions) > 0:
                # 检查第一个建议的结构
                first_suggestion = suggestions[0]
                if isinstance(first_suggestion, dict) and 'content' in first_suggestion:
                    return True
        return False
    except (json.JSONDecodeError, TypeError, KeyError):
        return False


async def call_remote_llm_api(system_prompt: str, user_prompt: str) -> str:
    """
    使用OpenAI client调用远程API服务商的LLM API
    返回完整的响应文本
    """
    try:
        # 构建消息
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
        
        logger.info(f"📡 调用远程API: {REMOTE_API_CONFIG['api_url']}")
        logger.info(f"📝 使用模型: {REMOTE_API_CONFIG['model_name']}")
        logger.info(f"💬 系统提示词长度: {len(system_prompt)} 字符")
        logger.info(f"💬 用户提示词长度: {len(user_prompt)} 字符")
        
        # 创建OpenAI客户端
        client = AsyncOpenAI(
            api_key=REMOTE_API_CONFIG["api_key"],
            base_url=REMOTE_API_CONFIG["api_url"]
        )
        
        # 调用非流式API
        logger.info("🔄 开始调用OpenAI非流式API...")
        response = await client.chat.completions.create(
            model=REMOTE_API_CONFIG["model_name"],
            messages=messages,
            temperature=REMOTE_API_CONFIG["temperature"],
            top_p=REMOTE_API_CONFIG["top_p"],
            stream=False
        )
        
        # 提取响应内容
        if response.choices and response.choices[0].message.content:
            content = response.choices[0].message.content
            
            # 过滤掉特殊标记
            filtered_content = filter_special_tokens(content)
            
            logger.info(f"📊 远程API调用完成，响应长度: {len(filtered_content)} 字符")
            return filtered_content
        else:
            logger.warning("⚠️ API响应为空")
            return ""
        
    except Exception as e:
        logger.error(f"❌ 远程API调用失败: {type(e).__name__}: {str(e)}")
        logger.error(f"❌ 错误堆栈: {traceback.format_exc()}")
        raise


def validate_remote_api_config():
    """
    验证远程API配置是否完整
    """
    required_fields = ["api_url", "api_key", "model_name"]
    
    for field in required_fields:
        if not REMOTE_API_CONFIG.get(field) or REMOTE_API_CONFIG[field] in [
            "http://",
            "https://api.your-provider.com/v1",
            "your-api-key-here",
            "your-model-name"
        ]:
            return False, f"请配置远程API参数: {field}"
    
    # 检查URL格式
    api_url = REMOTE_API_CONFIG["api_url"]
    if not api_url.startswith(("http://", "https://")):
        return False, "api_url必须以http://或https://开头"
    
    return True, "配置有效"


def load_llm_model():
    """
    加载LLM模型，在应用启动时调用
    使用ctransformers库从本地路径加载GGUF格式的模型
    如果本地模型加载失败，尝试使用远程API服务商
    """
    global llm_model, use_remote_llm
    
    # 首先尝试加载本地模型
    try:
        # 导入ctransformers
        from ctransformers import AutoModelForCausalLM
        
        # LLM模型路径配置
        llm_model_path = os.path.join(os.path.dirname(__file__), "..", "models", "llm", "Qwen3-4B-Q4_0.gguf")
        
        # 检查模型文件是否存在
        if not os.path.exists(llm_model_path):
            logger.warning(f"LLM模型文件不存在: {llm_model_path}")
            raise FileNotFoundError("本地模型文件不存在")
        
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
        logger.info("🔄 开始加载本地LLM模型...")
        model_loaded = False
        
        try:
            logger.info("📋 尝试方法1：使用标准参数加载模型")
            llm_model = AutoModelForCausalLM.from_pretrained(
                llm_model_path,
                model_type="qwen",  # 指定模型类型
                context_length=context_length,
                threads=threads,
                gpu_layers=-1 if gpu else 0,  # -1表示全部层使用GPU，0表示CPU
                stream=True,  # 启用流式输出
                local_files_only=True  # 只使用本地文件
            )
            model_loaded = True
            logger.info("✅ 方法1成功：标准参数加载完成")
            
        except Exception as e:
            error_msg = str(e)
            logger.warning(f"⚠️ 方法1失败: {error_msg}")
            
            # 尝试使用更保守的参数
            logger.info("📋 尝试方法2：使用保守参数重新加载LLM模型")
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
                model_loaded = True
                logger.info("✅ 方法2成功：保守参数加载完成")
                
            except Exception as e2:
                logger.warning(f"⚠️ 方法2失败: {str(e2)}")
                
                # 尝试自动检测模型类型
                logger.info("📋 尝试方法3：自动检测模型类型")
                try:
                    llm_model = AutoModelForCausalLM.from_pretrained(
                        llm_model_path,
                        context_length=2048,
                        threads=2,
                        gpu_layers=0,
                        stream=True,
                        local_files_only=True
                    )
                    model_loaded = True
                    logger.info("✅ 方法3成功：自动检测加载完成")
                    
                except Exception as e3:
                    logger.error(f"❌ 方法3失败: {str(e3)}")
                    logger.error("❌ 所有本地模型加载方法都失败，将切换到远程API")
        
        # 检查模型是否成功加载
        if model_loaded and llm_model is not None:
            logger.info("✅ 本地LLM模型加载成功")
            use_remote_llm = False
            return True
        else:
            logger.error("❌ 本地LLM模型加载完全失败")
            # 抛出异常以触发远程API回退
            raise Exception("所有本地模型加载方法都失败")
        
    except ImportError:
        logger.warning("ctransformers库未安装，尝试使用远程API")
    except Exception as e:
        logger.warning(f"本地LLM模型加载失败: {str(e)}，尝试使用远程API")
    
    # 本地模型加载失败，尝试使用远程API
    try:
        logger.info("🔄 尝试配置远程API作为备用方案...")
        
        # 验证远程API配置
        is_valid, message = validate_remote_api_config()
        if not is_valid:
            logger.error(f"❌ 远程API配置无效: {message}")
            logger.error("❌ 请在代码顶部的REMOTE_API_CONFIG中配置您的API服务商信息")
            logger.error("❌ 需要配置的字段: api_url, api_key, model_name")
            return False
        
        # 测试远程API连接
        logger.info("🔄 正在验证远程API配置...")
        
        # 这里不进行实际的API调用测试，只是标记使用远程API
        use_remote_llm = True
        llm_model = None  # 远程API不需要本地模型实例
        
        logger.info(f"✅ 已配置远程API: {REMOTE_API_CONFIG['api_url']}")
        logger.info(f"✅ 使用模型: {REMOTE_API_CONFIG['model_name']}")
        logger.info(f"✅ 温度设置: {REMOTE_API_CONFIG['temperature']}")
        logger.info(f"✅ Top-p设置: {REMOTE_API_CONFIG['top_p']}")
        logger.info("✅ 远程LLM API配置成功")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ 远程API配置失败: {type(e).__name__}: {str(e)}")
        logger.error(f"❌ 错误堆栈: {traceback.format_exc()}")
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
    logger.info("🚀 正在启动荣昶杯项目 API...")
    logger.info("=" * 50)
    
    # 初始化状态变量
    stt_success = False
    tts_success = False
    llm_success = False
    
    # 加载STT模型
    if MODEL_LOAD_CONFIG["load_stt"]:
        logger.info("🔄 开始加载STT模型...")
        stt_success = load_stt_model()
        if not stt_success:
            logger.warning("⚠️ STT模型加载失败，STT功能将不可用")
        else:
            logger.info("✅ STT模型加载成功")
    else:
        logger.info("⏭️ STT模型加载已禁用")
    
    # 加载TTS模型
    if MODEL_LOAD_CONFIG["load_tts"]:
        logger.info("🔄 开始加载TTS模型...")
        tts_success = load_tts_model()
        if not tts_success:
            logger.warning("⚠️ TTS模型加载失败，TTS功能将不可用")
        else:
            logger.info("✅ TTS模型加载成功")
    else:
        logger.info("⏭️ TTS模型加载已禁用")
    
    # 加载LLM模型
    if MODEL_LOAD_CONFIG["load_llm"]:
        logger.info("🔄 开始加载LLM模型...")
        llm_success = load_llm_model()
        if not llm_success:
            logger.warning("⚠️ LLM模型加载失败，LLM功能将不可用")
        else:
            logger.info("✅ LLM模型加载成功")
    else:
        logger.info("⏭️ LLM模型加载已禁用")
    
    # 启动总结
    logger.info("=" * 50)
    logger.info("📊 启动状态总结:")
    
    # STT状态
    if MODEL_LOAD_CONFIG["load_stt"]:
        logger.info(f"   STT: {'✅ 可用' if stt_success else '❌ 不可用'}")
    else:
        logger.info("   STT: ⏭️ 已禁用")
    
    # TTS状态
    if MODEL_LOAD_CONFIG["load_tts"]:
        logger.info(f"   TTS: {'✅ 可用' if tts_success else '❌ 不可用'}")
    else:
        logger.info("   TTS: ⏭️ 已禁用")
    
    # LLM状态
    if MODEL_LOAD_CONFIG["load_llm"]:
        logger.info(f"   LLM: {'✅ 可用' if llm_success else '❌ 不可用'}")
        logger.info(f"   服务模式: {'🌐 远程API' if use_remote_llm else '🏠 本地模型'}")
    else:
        logger.info("   LLM: ⏭️ 已禁用")
    
    logger.info("🎉 荣昶杯项目 API 启动完成!")
    logger.info("=" * 50)

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
    speaker: Optional[str] = None  # 多话者模型需要的说话人参数
    speaker_wav: Optional[str] = None  # XTTS模型需要的参考音频文件路径


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
    
    # 检查STT功能是否启用
    if not MODEL_LOAD_CONFIG["load_stt"]:
        raise HTTPException(status_code=503, detail="STT功能已禁用")
    
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


@app.get("/api/tts/speakers")
async def get_tts_speakers():
    """
    获取TTS模型可用的说话人列表和参考音频信息
    """
    global tts_model
    
    # 检查TTS功能是否启用
    if not MODEL_LOAD_CONFIG["load_tts"]:
        raise HTTPException(status_code=503, detail="TTS功能已禁用")
    
    if tts_model is None:
        raise HTTPException(status_code=503, detail="TTS模型未加载，服务不可用")
    
    try:
        speakers = []
        
        # 检查不同的说话人属性
        if hasattr(tts_model, 'speakers') and tts_model.speakers:
            speakers = list(tts_model.speakers)
        elif hasattr(tts_model, 'speaker_manager') and tts_model.speaker_manager:
            speakers = tts_model.speaker_manager.speaker_names
        
        # 检查默认参考音频文件
        default_reference_path = os.path.join(os.path.dirname(__file__), "..", "models", "tts", "samples", "zh-cn-sample.wav")
        reference_audio_available = os.path.exists(default_reference_path)
        
        return {
            "speakers": speakers,
            "default_speaker": speakers[0] if speakers else None,
            "is_multi_speaker": len(speakers) > 1,
            "reference_audio": {
                "default_path": "backend/models/tts/samples/zh-cn-sample.wav",
                "available": reference_audio_available,
                "absolute_path": default_reference_path
            },
            "xtts_support": True,  # 表示支持XTTS模型
            "usage_note": "XTTS模型需要参考音频文件来克隆声音，如果不提供speaker_wav参数将使用默认参考音频"
        }
    except Exception as e:
        logger.error(f"📋 获取说话人列表失败: {e}")
        return {
            "speakers": [],
            "default_speaker": None,
            "is_multi_speaker": False,
            "reference_audio": {
                "available": False,
                "error": str(e)
            },
            "error": str(e)
        }


@app.post("/api/tts")
async def text_to_speech(request: TTSRequest):
    """
    文字转语音 API
    
    接收文本并返回音频流
    使用Coqui TTS模型进行语音合成
    """
    global tts_model
    
    # 检查TTS功能是否启用
    if not MODEL_LOAD_CONFIG["load_tts"]:
        raise HTTPException(status_code=503, detail="TTS功能已禁用")
    
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
        logger.info(f"🔊 正在合成语音: {request.text[:50]}...")
        
        # 处理XTTS参考音频文件
        reference_audio_path = None
        if request.speaker_wav:
            # 用户指定了参考音频文件
            reference_audio_path = request.speaker_wav
        else:
            # 使用默认的参考音频文件
            default_reference_path = os.path.join(os.path.dirname(__file__), "..", "models", "tts", "samples", "zh-cn-sample.wav")
            if os.path.exists(default_reference_path):
                reference_audio_path = default_reference_path
                logger.info(f"🎵 使用默认参考音频: {reference_audio_path}")
            else:
                logger.warning(f"⚠️ 默认参考音频文件不存在: {default_reference_path}")
        
        # 检查参考音频文件是否存在
        if not reference_audio_path or not os.path.exists(reference_audio_path):
            raise HTTPException(status_code=400, detail="XTTS模型需要参考音频文件，但未找到可用的参考音频")
        
        logger.info(f"🎵 使用参考音频文件: {reference_audio_path}")
        
        # 按照官方API方式调用TTS模型
        logger.info("🔄 开始TTS模型音频生成...")
        tts_model.tts_to_file(
            text=request.text,
            file_path=temp_audio_path,
            speaker_wav=reference_audio_path,
            language="zh-cn"  # 使用中文语言
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


@app.post("/api/generate_suggestions", response_model=GenerateSuggestionsResponse)
async def generate_suggestions(request: GenerateSuggestionsRequest):
    """
    生成回答建议 API
    
    根据上下文信息生成多个回答建议，返回完整的JSON响应
    支持本地模型和远程API服务商
    """
    global llm_model, use_remote_llm
    
    logger.info("🚀 开始处理生成建议请求")
    logger.info(f"📋 请求参数: {request.dict()}")
    
    # 检查LLM功能是否启用
    if not MODEL_LOAD_CONFIG["load_llm"]:
        logger.error("❌ LLM功能已禁用")
        raise HTTPException(status_code=503, detail="LLM功能已禁用")
    
    # 检查是否有可用的LLM服务
    if not use_remote_llm and llm_model is None:
        logger.error("❌ LLM服务未配置")
        raise HTTPException(status_code=503, detail="LLM服务未配置，请检查本地模型或远程API配置")
    
    try:
        # 加载系统提示词
        logger.info("📖 加载系统提示词...")
        system_prompt = load_system_prompt()
        logger.info(f"📖 系统提示词长度: {len(system_prompt)} 字符")
        
        # 构建结构化的用户Prompt
        logger.info("🔧 构建用户提示词...")
        user_prompt = build_structured_prompt(request)
        logger.info(f"🔧 用户提示词长度: {len(user_prompt)} 字符")
        logger.debug(f"📝 用户提示词内容: {user_prompt}")
        
        service_type = "远程API" if use_remote_llm else "本地模型"
        logger.info(f"⚙️ 开始生成建议，使用 {service_type}")
        
    except Exception as e:
        logger.error(f"❌ 请求预处理失败: {type(e).__name__}: {str(e)}")
        logger.error(f"❌ 错误堆栈: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"请求预处理失败: {str(e)}")
    
    try:
        start_time = time.time()
        accumulated_text = ""
        logger.info("🔄 开始生成建议...")
        
        if use_remote_llm:
            # 使用远程API服务商
            logger.info("🌐 使用远程API生成建议")
            accumulated_text = await call_remote_llm_api(system_prompt, user_prompt)
            
        else:
            # 使用本地模型
            logger.info("🏠 使用本地模型生成建议")
            
            # 应用Qwen2聊天模板
            logger.info("📝 应用Qwen2聊天模板...")
            formatted_prompt = apply_qwen2_chat_template(system_prompt, user_prompt)
            logger.info(f"📝 格式化后的提示词长度: {len(formatted_prompt)} 字符")
            logger.debug(f"📝 格式化后的提示词: {formatted_prompt}")
            
            # ctransformers非流式生成
            logger.info("🔄 开始本地模型非流式生成...")
            raw_text = llm_model(
                formatted_prompt,
                max_new_tokens=1024,
                temperature=0.7,
                top_p=0.9,
                stop=["<|im_end|>", "<|endoftext|>"],
                stream=False,
                reset=False  # 不重置对话历史
            )
            
            # 过滤掉特殊标记
            accumulated_text = filter_special_tokens(raw_text)
            logger.info(f"📊 本地模型生成完成，响应长度: {len(accumulated_text)} 字符")
        
        # 计算处理时间
        processing_time = time.time() - start_time
        logger.info(f"⏱️ 总处理时间: {processing_time:.2f}秒")
        
        # 解析JSON结果
        logger.info("🔄 开始解析JSON结果...")
        suggestions = []
        
        try:
            # 使用强健的JSON提取函数
            logger.debug(f"📝 原始文本: {accumulated_text[:200]}...")
            json_text = extract_json_from_text(accumulated_text)
            logger.info(f"📝 提取的JSON长度: {len(json_text)} 字符")
            
            logger.info("🔄 尝试解析JSON...")
            result = json.loads(json_text)
            logger.info(f"✅ JSON解析成功: {result}")
            
            # 验证JSON结构符合Schema
            if 'suggestions' in result and isinstance(result['suggestions'], list):
                suggestions = result['suggestions']
                logger.info(f"✅ 找到 {len(suggestions)} 个建议")
                
                # 验证每个建议的结构
                for i, suggestion in enumerate(suggestions):
                    if not all(key in suggestion for key in ['id', 'content', 'confidence']):
                        logger.warning(f"⚠️ 建议 {i+1} 格式不完整: {suggestion}")
                        raise ValueError(f"建议 {i+1} 格式不完整")
                    logger.debug(f"✅ 建议 {i+1} 格式正确")
            else:
                logger.error("❌ JSON结构不符合预期，缺少suggestions字段或类型错误")
                raise ValueError("JSON结构不符合预期")
            
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"⚠️ JSON解析失败: {type(e).__name__}: {str(e)}")
            logger.warning(f"⚠️ 原始文本前200字符: {accumulated_text[:200]}...")
            logger.warning(f"⚠️ 提取的JSON文本: {json_text[:200] if 'json_text' in locals() else 'N/A'}...")
            logger.warning("⚠️ 创建包含原始文本的响应")
            
            # 尝试从原始文本中提取有意义的内容作为建议
            content_text = accumulated_text.strip()
            
            # 如果文本太长，尝试找到关键部分
            if len(content_text) > 500:
                # 寻找可能的建议内容
                lines = content_text.split('\n')
                meaningful_lines = []
                for line in lines:
                    line = line.strip()
                    if line and not line.startswith(('思考', '分析', '考虑', '<', '```', '#')):
                        meaningful_lines.append(line)
                        if len('\n'.join(meaningful_lines)) > 300:
                            break
                
                if meaningful_lines:
                    content_text = '\n'.join(meaningful_lines)
                else:
                    content_text = content_text[:300] + "..."
            
            # 如果JSON解析失败，创建包含提取内容的响应
            suggestions = [
                {
                    "id": 1,
                    "content": content_text,
                    "confidence": 0.60
                }
            ]
        
        # 返回最终结果
        logger.info("✅ 生成建议完成")
        return GenerateSuggestionsResponse(
            suggestions=[Suggestion(**s) for s in suggestions],
            processing_time=processing_time
        )
        
    except Exception as e:
        logger.error(f"❌ LLM生成失败: {type(e).__name__}: {str(e)}")
        logger.error(f"❌ 错误堆栈: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500, 
            detail=f"生成建议失败: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)