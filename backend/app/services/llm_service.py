"""
LLM (Large Language Model) 服务
基于OpenRouter API实现
"""
import asyncio
import logging
import json
from typing import List, Optional, Dict, Any
from datetime import datetime

from config.settings import settings
from app.models.session import Session, Message

logger = logging.getLogger(__name__)


class LLMService:
    """OpenRouter LLM服务管理器"""
    
    def __init__(self):
        self.is_initialized = False
        self.client = None
        self.opinion_system_prompt = ""
        self.response_system_prompt = ""
        
    async def initialize(self) -> bool:
        """
        初始化LLM服务
        
        Returns:
            bool: 初始化是否成功
        """
        try:
            # 检查API密钥
            if not settings.openrouter_api_key:
                logger.warning("OpenRouter API密钥未配置，使用Mock模式")
                self.is_initialized = True
                return True
            
            # TODO: 初始化真实的OpenRouter客户端
            # 目前使用Mock模式
            
            # 加载系统提示词
            await self._load_system_prompts()
            
            self.is_initialized = True
            logger.info("LLM服务初始化完成（Mock模式）")
            
            return True
            
        except Exception as e:
            logger.error(f"LLM服务初始化失败: {e}")
            return False
    
    async def _load_system_prompts(self):
        """加载系统提示词"""
        try:
            # 1. 为“意见生成”任务创建独立的、专注分析的系统提示词
            self.opinion_system_prompt = """## Persona: 客观中立的对话分析师

你的唯一任务是精准、客观地分析给定的对话内容，并提炼出核心的意见倾向或情感主题。

### 你的行为准则
- **绝对中立**: 你不表达任何观点，只作为镜子反映对话内容。
- **高度概括**: 你的输出必须是精炼的关键词或短语。
- **聚焦核心**: 你的分析应直指对话的要点、争议点或情感核心。
- **严格遵循格式**: 你必须严格按照指定的JSON格式返回结果。"""

            # 2. 为“回答生成”任务加载并配置主系统提示词
            import os
            llm_prompt_path = os.path.join(os.getcwd(), "llm.md")
            
            if os.path.exists(llm_prompt_path):
                with open(llm_prompt_path, 'r', encoding='utf-8') as f:
                    base_prompt = f.read().strip()
                
                # 将加载的主提示词用于回答生成
                self.response_system_prompt = base_prompt
                logger.info("主系统提示词 (llm.md) 加载成功")
            else:
                logger.warning(f"主系统提示词文件不存在: {llm_prompt_path}，使用默认回答生成提示词")
                self.response_system_prompt = """你是一个专业的沟通助手。请根据对话内容生成多个不同风格的回答建议，包括简洁直接、礼貌委婉、幽默友好等不同风格。每个建议都应该完整、自然、适合对话语境。返回JSON格式。"""

            logger.info("系统提示词加载和配置完成")

        except Exception as e:
            logger.error(f"加载系统提示词失败: {e}")
            self._set_default_prompts()
    
    def _set_default_prompts(self):
        """设置默认系统提示词"""
        self.opinion_system_prompt = """你是一个专业的对话分析助手。请根据对话内容生成3-5个意见倾向关键词，帮助用户理解对话中的不同观点。关键词应该简洁明了，反映情感和态度倾向。返回JSON格式。"""
        
        self.response_system_prompt = """你是一个专业的沟通助手。请根据对话内容生成多个不同风格的回答建议，包括简洁直接、礼貌委婉、幽默友好等不同风格。每个建议都应该完整、自然、适合对话语境。返回JSON格式。"""
    
    async def shutdown(self):
        """关闭LLM服务"""
        try:
            # TODO: 清理OpenRouter客户端资源
            
            self.is_initialized = False
            logger.info("LLM服务已关闭")
            
        except Exception as e:
            logger.error(f"LLM服务关闭时发生错误: {e}")
    
    async def generate_opinions(self, session: Session) -> List[str]:
        """
        生成意见倾向关键词
        
        Args:
            session: 会话对象
            
        Returns:
            List[str]: 意见倾向关键词列表
        """
        if not self.is_initialized:
            logger.error("LLM服务未初始化")
            return []
        
        try:
            # 构建提示词
            prompt = self._format_opinion_prompt(session)
            
            # 调用LLM
            response = await self._call_llm(
                prompt, 
                response_format="opinion",
                max_tokens=200
            )
            
            if response and "suggestions" in response:
                suggestions = response["suggestions"]
                logger.info(f"意见生成完成: {len(suggestions)} 个建议")
                return suggestions[:5]  # 最多返回5个
            else:
                logger.warning("LLM返回格式异常")
                return self._get_mock_opinions()
                
        except Exception as e:
            logger.error(f"生成意见建议失败: {e}")
            return self._get_mock_opinions()
    
    async def generate_responses(self, session: Session, count: int = 3) -> List[str]:
        """
        生成回答建议
        
        Args:
            session: 会话对象
            count: 生成数量
            
        Returns:
            List[str]: 回答建议列表
        """
        if not self.is_initialized:
            logger.error("LLM服务未初始化")
            return []
        
        try:
            # 构建提示词
            prompt = self._format_response_prompt(session, count)
            
            # 调用LLM
            response = await self._call_llm(
                prompt,
                response_format="response",
                max_tokens=800,
                count=count
            )
            
            if response and "suggestions" in response:
                suggestions = response["suggestions"]
                logger.info(f"回答生成完成: {len(suggestions)} 个建议")
                return suggestions[:count]
            else:
                logger.warning("LLM返回格式异常")
                return self._get_mock_responses(count)
                
        except Exception as e:
            logger.error(f"生成回答建议失败: {e}")
            return self._get_mock_responses(count)
    
    def _format_opinion_prompt(self, session: Session) -> str:
        """
        格式化意见生成提示词
        
        Args:
            session: 会话对象
            
        Returns:
            str: 格式化的提示词
        """
        parts = [self.opinion_system_prompt]
        
        # 添加对话情景
        if session.scenario_description:
            parts.append(f"\n## 对话情景\n{session.scenario_description}")
        
        # 添加消息历史
        if session.messages:
            parts.append("\n## 待分析的消息历史")
            for message in session.messages:
                parts.append(f"消息{message.id} - {message.sender}: {message.content}")
        
        parts.append("\n## 分析要求\n请基于以上对话，生成3-5个精准概括核心观点的意见关键词。")
        
        return "\n".join(parts)
    
    def _format_response_prompt(self, session: Session, count: int) -> str:
        """
        格式化回答生成提示词
        
        Args:
            session: 会话对象
            count: 生成数量
            
        Returns:
            str: 格式化的提示词
        """
        parts = [self.response_system_prompt]
        
        # 添加对话情景
        if session.scenario_description:
            parts.append(f"\n## 对话情景\n{session.scenario_description}")
        
        # 添加消息历史
        if session.messages:
            parts.append("\n## 消息历史")
            for message in session.messages:
                parts.append(f"消息{message.id} - {message.sender}: {message.content}")
        
        # 添加聚焦消息
        focused_messages = session.get_focused_messages()
        if focused_messages:
            parts.append("\n## 聚焦消息\n用户特别关注以下消息：")
            for message in focused_messages:
                parts.append(f"消息{message.id} - {message.sender}: {message.content}")
        
        # 添加用户意见倾向
        if session.user_opinion:
            parts.append(f"\n## 用户意见倾向\n{session.user_opinion}")
        
        # 添加修改建议
        if session.modifications:
            parts.append("\n## 修改建议")
            for i, modification in enumerate(session.modifications, 1):
                parts.append(f"{i}. {modification}")
        
        # 添加生成要求
        parts.append(f"\n## 任务指令\n请激活你的“沟通辅助能力”，综合以上所有信息，为用户生成 {count} 个高质量、多样化的建议回答。")
        
        return "\n".join(parts)
    
    async def _call_llm(self, prompt: str, response_format: str = "auto", max_tokens: int = None, count: int = 3) -> Optional[Dict[str, Any]]:
        """
        调用LLM API
        
        Args:
            prompt: 提示词
            response_format: 响应格式类型
            max_tokens: 最大token数
            count: 生成数量（用于response格式）
            
        Returns:
            Optional[Dict[str, Any]]: LLM响应
        """
        try:
            if not settings.openrouter_api_key:
                # Mock模式
                await asyncio.sleep(0.5)  # 模拟API延迟
                
                if response_format == "opinion":
                    return {"suggestions": self._get_mock_opinions()}
                else:
                    return {"suggestions": self._get_mock_responses(count)}
            
            # TODO: 实际的OpenRouter API调用
            # 这里应该实现真实的API调用逻辑
            
            # 临时返回Mock数据
            await asyncio.sleep(0.5)
            
            if response_format == "opinion":
                return {"suggestions": self._get_mock_opinions()}
            else:
                return {"suggestions": self._get_mock_responses(count)}
                
        except Exception as e:
            logger.error(f"LLM API调用失败: {e}")
            return None
    
    def _get_mock_opinions(self) -> List[str]:
        """获取Mock意见建议"""
        return [
            "积极乐观",
            "谨慎保守", 
            "理性分析",
            "情感共鸣",
            "实用主义"
        ]
    
    def _get_mock_responses(self, count: int) -> List[str]:
        """获取Mock回答建议"""
        responses = [
            "我理解您的观点，这确实是一个值得深入思考的问题。",
            "您说得很有道理，不过我觉得可能还有另一个角度可以考虑。",
            "哈哈，这个想法很有趣！我也有类似的经历。",
            "能具体说说您是怎么想的吗？我很好奇您的具体考虑。",
            "谢谢您的分享，这让我学到了很多新的东西。"
        ]
        
        return responses[:count]
    
    async def health_check(self) -> Dict[str, Any]:
        """
        健康检查
        
        Returns:
            Dict[str, Any]: 健康状态信息
        """
        return {
            "service": "LLM",
            "status": "healthy" if self.is_initialized else "unhealthy",
            "initialized": self.is_initialized,
            "api_configured": bool(settings.openrouter_api_key),
            "base_url": settings.openrouter_base_url,
            "mode": "mock" if not settings.openrouter_api_key else "openrouter"
        }


# ===============================
# 真实的OpenRouter集成代码（待启用）
# ===============================

class OpenRouterLLMService(LLMService):
    """
    真实的OpenRouter LLM服务实现
    
    注意：需要安装openai库并配置API密钥
    pip install openai
    """
    
    def __init__(self):
        super().__init__()
        self.api_client = None
    
    async def initialize(self) -> bool:
        """初始化真实的OpenRouter服务"""
        try:
            from openai import AsyncOpenAI
            
            if not settings.openrouter_api_key:
                logger.error("OpenRouter API密钥未配置")
                return False
            
            # 创建OpenRouter客户端
            self.api_client = AsyncOpenAI(
                api_key=settings.openrouter_api_key,
                base_url=settings.openrouter_base_url
            )
            
            # 加载系统提示词
            await self._load_system_prompts()
            
            self.is_initialized = True
            logger.info("OpenRouter LLM服务初始化完成")
            
            return True
            
        except ImportError:
            logger.error("OpenAI库未安装，请运行: pip install openai")
            return False
        except Exception as e:
            logger.error(f"OpenRouter LLM服务初始化失败: {e}")
            return False
    
    async def _call_llm(self, prompt: str, response_format: str = "auto", max_tokens: int = None, count: int = 3) -> Optional[Dict[str, Any]]:
        """真实的OpenRouter API调用"""
        if not self.api_client:
            return None
        
        try:
            # 使用配置中的参数
            if max_tokens is None:
                max_tokens = settings.openrouter_max_tokens
            
            # 构建响应格式
            format_schema = None
            if response_format == "opinion":
                format_schema = {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "opinion_suggestions",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "suggestions": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "意见倾向关键词数组"
                                }
                            },
                            "required": ["suggestions"]
                        }
                    }
                }
            elif response_format == "response":
                format_schema = {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "response_suggestions",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "suggestions": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "回答建议数组"
                                }
                            },
                            "required": ["suggestions"]
                        }
                    }
                }
            
            # 调用API - 使用配置中的模型和参数
            response = await self.api_client.chat.completions.create(
                model=settings.openrouter_model,
                messages=[
                    {"role": "user", "content": prompt}
                ],
                max_tokens=max_tokens,
                temperature=settings.openrouter_temperature,
                response_format=format_schema
            )
            
            # 解析响应
            content = response.choices[0].message.content
            return json.loads(content)
            
        except Exception as e:
            logger.error(f"OpenRouter API调用失败: {e}")
            return None
    
    async def health_check(self) -> Dict[str, Any]:
        """OpenRouter健康检查"""
        base_status = await super().health_check()
        base_status.update({
            "mode": "openrouter",
            "client_initialized": self.api_client is not None
        })
        return base_status


# 根据配置选择使用哪个实现
def create_llm_service() -> LLMService:
    """
    创建LLM服务实例
    
    Returns:
        LLMService: LLM服务实例
    """
    # 可以通过环境变量或配置文件控制
    use_real_openrouter = bool(settings.openrouter_api_key)
    
    if use_real_openrouter:
        return OpenRouterLLMService()
    else:
        return LLMService()  # Mock版本