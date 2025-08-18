#!/usr/bin/env python3
"""
Whisper模型下载和转换脚本

此脚本用于下载Whisper模型并转换为CTranslate2格式，以便faster-whisper使用。

使用方法:
python scripts/download_whisper_models.py --model base --output model/whisper-models

支持的模型: tiny, base, small, medium, large, large-v2, large-v3, distil-large-v3
"""

import os
import sys
import argparse
import logging
from pathlib import Path

# 添加项目根目录到Python路径
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from config.settings import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SUPPORTED_MODELS = [
    "tiny", "base", "small", "medium", 
    "large", "large-v2", "large-v3", 
    "distil-large-v3"
]

def download_and_convert_model(model_name: str, output_dir: str, quantization: str = "int8"):
    """
    下载并转换Whisper模型
    
    Args:
        model_name: 模型名称
        output_dir: 输出目录
        quantization: 量化类型
    """
    try:
        import ctranslate2
        from ctranslate2.converters import TransformersConverter
        import transformers
        
        logger.info(f"开始下载和转换Whisper模型: {model_name}")
        
        # 创建输出目录
        output_path = Path(output_dir) / f"{model_name}-ct2"
        output_path.mkdir(parents=True, exist_ok=True)
        
        # 检查模型是否已存在
        if (output_path / "config.json").exists():
            logger.info(f"模型已存在: {output_path}")
            return str(output_path)
        
        # 构建Hugging Face模型名称
        if model_name.startswith("distil-"):
            hf_model_name = f"distil-whisper/{model_name}"
        else:
            hf_model_name = f"openai/whisper-{model_name}"
        
        logger.info(f"从Hugging Face下载模型: {hf_model_name}")
        logger.info(f"输出路径: {output_path}")
        logger.info(f"量化类型: {quantization}")
        
        # 转换模型
        converter = TransformersConverter(
            model_name_or_path=hf_model_name,
            output_dir=str(output_path),
            copy_files=["tokenizer.json", "preprocessor_config.json"],
            quantization=quantization,
            low_cpu_mem_usage=True
        )
        
        converter.convert()
        
        logger.info(f"模型转换完成: {output_path}")
        return str(output_path)
        
    except ImportError as e:
        logger.error("缺少必要的库，请安装:")
        logger.error("pip install ctranslate2 transformers[torch]")
        raise e
    except Exception as e:
        logger.error(f"模型下载/转换失败: {e}")
        raise e

def verify_model(model_path: str) -> bool:
    """
    验证转换的模型是否可用
    
    Args:
        model_path: 模型路径
        
    Returns:
        bool: 模型是否可用
    """
    try:
        from faster_whisper import WhisperModel
        
        logger.info(f"验证模型: {model_path}")
        
        # 尝试加载模型
        model = WhisperModel(model_path, device="cpu", compute_type="int8")
        
        logger.info("模型验证成功!")
        return True
        
    except ImportError:
        logger.warning("faster-whisper未安装，跳过模型验证")
        return True
    except Exception as e:
        logger.error(f"模型验证失败: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="下载和转换Whisper模型")
    parser.add_argument(
        "--model", 
        choices=SUPPORTED_MODELS,
        default="base",
        help="要下载的模型名称"
    )
    parser.add_argument(
        "--output",
        default="model/whisper-models",
        help="模型输出目录"
    )
    parser.add_argument(
        "--quantization",
        choices=["float32", "float16", "int8", "int8_float16"],
        default="int8",
        help="量化类型"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="验证转换的模型"
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="下载所有推荐的模型"
    )
    
    args = parser.parse_args()
    
    # 创建输出目录
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    if args.all:
        # 下载推荐模型
        recommended_models = ["base", "small", "medium"]
        logger.info(f"下载推荐模型: {recommended_models}")
        
        for model_name in recommended_models:
            try:
                model_path = download_and_convert_model(
                    model_name, 
                    str(output_dir), 
                    args.quantization
                )
                
                if args.verify:
                    verify_model(model_path)
                    
            except Exception as e:
                logger.error(f"处理模型 {model_name} 失败: {e}")
                continue
    else:
        # 下载单个模型
        try:
            model_path = download_and_convert_model(
                args.model, 
                str(output_dir), 
                args.quantization
            )
            
            if args.verify:
                verify_model(model_path)
                
        except Exception as e:
            logger.error(f"处理失败: {e}")
            sys.exit(1)
    
    logger.info("模型处理完成!")
    logger.info(f"模型位置: {output_dir}")
    logger.info("使用说明:")
    logger.info(f"  在配置文件中设置 WHISPER_MODEL_PATH={output_dir}")
    logger.info(f"  设置 WHISPER_MODEL_NAME 为您选择的模型名称")

if __name__ == "__main__":
    main()