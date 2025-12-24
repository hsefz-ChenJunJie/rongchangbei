"""
LLM (Large Language Model) 服务
基于OpenRouter API实现
"""
import asyncio
import logging
import json
import os
from pathlib import Path
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
        self.response_system_prompt = ""
        self.opinion_system_prompt = ""
        self.response_generation_requirements = ""
        self.prompt_log_file = getattr(settings, "llm_prompt_log_file", "logs/llm_prompts.log")
        # 固定提示词目录为 backend/prompts（与 app 同级），避免依赖运行目录
        self.prompts_dir = Path(__file__).resolve().parents[2] / "prompts"
        
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
            # 为“回答生成”任务加载并配置主系统提示词
            base_dir = str(self.prompts_dir)
            llm_prompt_paths = [
                os.path.join(base_dir, "llm.md"),
                os.path.join(os.getcwd(), "backend", "llm.md"),  # 兼容旧路径
            ]
            opinion_prompt_paths = [
                os.path.join(base_dir, "opinion_prediction_prompt.md"),
                os.path.join(os.getcwd(), "backend", "opinion_prediction_prompt.md"),  # 兼容旧路径
            ]
            response_requirements_paths = [
                os.path.join(base_dir, "response_generation_requirements.md"),
            ]
            default_response_path = os.path.join(base_dir, "default_response_system.md")
            default_opinion_path = os.path.join(base_dir, "default_opinion_system.md")
            default_requirements_path = os.path.join(base_dir, "default_response_generation_requirements.md")

            self.response_system_prompt = self._load_first_existing(llm_prompt_paths, default_response_path)
            self.opinion_system_prompt = self._load_first_existing(opinion_prompt_paths, default_opinion_path)
            self.response_generation_requirements = self._load_first_existing(response_requirements_paths, default_requirements_path)

            logger.info("系统提示词加载和配置完成")

        except Exception as e:
            logger.error(f"加载系统提示词失败: {e}")
            self._set_default_prompts()
    
    def _set_default_prompts(self):
        """设置默认系统提示词"""
        base_dir = str(self.prompts_dir)
        default_response_path = os.path.join(base_dir, "default_response_system.md")
        default_opinion_path = os.path.join(base_dir, "default_opinion_system.md")
        default_requirements_path = os.path.join(base_dir, "default_response_generation_requirements.md")
        self.response_system_prompt = self._read_prompt_file(default_response_path)
        self.opinion_system_prompt = self._read_prompt_file(default_opinion_path)
        self.response_generation_requirements = self._read_prompt_file(default_requirements_path)
    
    async def shutdown(self):
        """关闭LLM服务"""
        try:
            # TODO: 清理OpenRouter客户端资源
            
            self.is_initialized = False
            logger.info("LLM服务已关闭")
            
        except Exception as e:
            logger.error(f"LLM服务关闭时发生错误: {e}")
    
    async def generate_responses(
        self, 
        session: Session, 
        count: int = 3,
        focused_message_ids: Optional[List[str]] = None,
        user_opinion: Optional[str] = None,
        user_context: Optional[Dict[str, Optional[str]]] = None
    ) -> List[str]:
        """
        生成回答建议
        
        Args:
            session: 会话对象
            count: 生成数量
            focused_message_ids: 聚焦消息ID列表
            user_opinion: 用户意见
            user_context: 用户上下文信息，包含语料库、背景、偏好、近期经历等
            
        Returns:
            List[str]: 回答建议列表
        """
        if not self.is_initialized:
            logger.error("LLM服务未初始化")
            return []
        
        try:
            user_context = user_context or {}
            # 构建提示词
            user_prompt = self._format_response_prompt(
                session=session,
                count=count,
                focused_message_ids=focused_message_ids,
                user_opinion=user_opinion,
                user_context=user_context,
            )
            system_prompt = self._build_response_system_prompt(count)
            messages = self._build_messages(
                system_prompt=system_prompt,
                user_prompt=user_prompt
            )
            self._log_prompt(
                session_id=session.id,
                request_type="response",
                prompt=user_prompt,
                system_prompt=system_prompt,
                extra={
                    "response_count": count,
                    "focused_message_ids": focused_message_ids or [],
                    "user_opinion": user_opinion,
                    "has_user_corpus": bool(user_context.get("corpus") or session.user_corpus),
                    "has_user_background": bool(user_context.get("background") or session.user_background),
                    "has_user_preferences": bool(user_context.get("preferences") or session.user_preferences),
                    "has_user_recent_experiences": bool(
                        user_context.get("recent_experiences") or session.user_recent_experiences
                    ),
                },
            )
            
            # 调用LLM
            response = await self._call_llm(
                messages,
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
    
    def _format_response_prompt(
        self, 
        session: Session, 
        count: int,
        focused_message_ids: Optional[List[str]] = None,
        user_opinion: Optional[str] = None,
        user_context: Optional[Dict[str, Optional[str]]] = None
    ) -> str:
        """
        格式化回答生成提示词
        
        Args:
            session: 会话对象
            count: 生成数量
            focused_message_ids: 聚焦消息ID列表
            user_opinion: 用户意见
            user_context: 用户上下文信息
            
        Returns:
            str: 格式化的提示词
        """
        parts: List[str] = []
        ctx = user_context or {}
        user_corpus = ctx.get("corpus") or session.user_corpus
        user_background = ctx.get("background") or session.user_background
        user_preferences = ctx.get("preferences") or session.user_preferences
        user_recent_experiences = ctx.get("recent_experiences") or session.user_recent_experiences
        
        # 添加对话情景
        if session.scenario_description:
            parts.append(f"## 对话情景\n{session.scenario_description}")
        
        # 用户背景、偏好、经历与语料
        if user_background:
            parts.append(f"## 用户背景\n{user_background}")
        if user_preferences:
            parts.append(f"## 用户偏好\n{user_preferences}")
        if user_recent_experiences:
            parts.append(f"## 用户近期经历\n{user_recent_experiences}")
        if user_corpus:
            parts.append(f"## 用户参考语料\n{user_corpus}")
        
        # 用户倾向
        if user_opinion:
            parts.append(f"## 用户倾向\n{user_opinion}")
        
        # 添加消息历史
        if session.messages:
            parts.append("## 对话内容")
            for message in session.messages:
                parts.append(f"{message.sender}: {message.content}")
        
        # 添加聚焦消息
        if focused_message_ids:
            focused_messages = session.get_focused_messages(focused_message_ids)
            if focused_messages:
                parts.append("## 重点关注内容")
                for message in focused_messages:
                    parts.append(f"{message.sender}: {message.content}")

        # 添加修改建议
        if session.modifications:
            parts.append("## 调整要求")
            for modification in session.modifications:
                parts.append(f"- {modification}")
        
        return "\n\n".join(parts)

    async def generate_opinion_prediction(
        self, 
        session: Session,
        last_message_content: str
    ) -> Optional[Dict[str, str]]:
        """
        生成意见预测
        
        Args:
            session: 会话对象
            last_message_content: 用户最后选择的消息内容
            
        Returns:
            Optional[Dict[str, str]]: 包含tendency, mood, tone的预测字典
        """
        if not self.is_initialized:
            logger.error("LLM服务未初始化")
            return None
        
        try:
            user_prompt = self._format_opinion_prediction_prompt(session, last_message_content)
            messages = self._build_messages(
                system_prompt=self.opinion_system_prompt,
                user_prompt=user_prompt
            )
            self._log_prompt(
                session_id=session.id,
                request_type="opinion_prediction",
                prompt=user_prompt,
                system_prompt=self.opinion_system_prompt,
                extra={
                    "last_selected_response": last_message_content,
                    "message_count": len(session.messages),
                },
            )
            
            response = await self._call_llm(
                messages,
                response_format="opinion_prediction",
                max_tokens=200
            )
            
            if response and "prediction" in response:
                prediction = response["prediction"]
                logger.info(f"意见预测完成: {prediction}")
                return prediction
            else:
                logger.warning("LLM返回格式异常 (意见预测)")
                return None
                
        except Exception as e:
            logger.error(f"生成意见预测失败: {e}")
            return None

    def _format_opinion_prediction_prompt(
        self, 
        session: Session, 
        last_message_content: str
    ) -> str:
        """
        格式化意见预测提示词
        
        Args:
            session: 会话对象
            last_message_content: 用户最后选择的消息内容

        Returns:
            str: 格式化的提示词
        """
        parts: List[str] = []
        
        if session.messages:
            parts.append("## 对话内容")
            for message in session.messages:
                parts.append(f"{message.sender}: {message.content}")

        parts.append("## 用户最后选择的回答")
        parts.append(last_message_content)
        
        parts.append("## 任务要求\n请基于以上信息，分析并预测用户下一次发言可能的心态。")
        
        return "\n\n".join(parts)
    
    async def _call_llm(
        self,
        messages: List[Dict[str, str]],
        response_format: str = "auto",
        max_tokens: int = None,
        count: int = 3
    ) -> Optional[Dict[str, Any]]:
        """
        调用LLM API（当前为Mock实现）

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
                return {"suggestions": self._get_mock_responses(count)}

            # TODO: 实际的OpenRouter API调用
            # 这里应该实现真实的API调用逻辑
            await asyncio.sleep(0.5)
            return {"suggestions": self._get_mock_responses(count)}

        except Exception as e:
            logger.error(f"LLM API调用失败: {e}")
            return None

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

    def _read_prompt_file(self, path: str) -> str:
        """读取提示词文件内容"""
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read().strip()
        except Exception as e:
            logger.error(f"读取提示词文件失败: {path}, {e}")
            return ""

    def _load_first_existing(self, paths: List[str], default_path: str) -> str:
        """按顺序加载第一个存在的提示词文件，否则回退到默认文件"""
        for path in paths:
            if os.path.exists(path):
                return self._read_prompt_file(path)
        return self._read_prompt_file(default_path)

    def _log_prompt(self, session_id: str, request_type: str, prompt: str, system_prompt: Optional[str] = None, extra: Optional[Dict[str, Any]] = None):
        """将提示词和上下文写入独立日志文件，便于调试"""
        try:
            if not self.prompt_log_file:
                return
            log_dir = os.path.dirname(self.prompt_log_file) or "."
            os.makedirs(log_dir, exist_ok=True)

            record = {
                "timestamp": datetime.utcnow().isoformat(),
                "session_id": session_id,
                "request_type": request_type,
                "prompt": prompt,
            }
            if system_prompt:
                record["system_prompt"] = system_prompt
            if extra:
                record.update(extra)

            with open(self.prompt_log_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(record, ensure_ascii=False) + "\n")
        except Exception as e:
            logger.error(f"写入LLM提示词日志失败: {e}")

    def _build_messages(self, system_prompt: str, user_prompt: str) -> List[Dict[str, str]]:
        """构建 chat messages，确保 persona 放入 system，上下文放入 user"""
        return [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

    def _build_response_system_prompt(self, count: int) -> str:
        """拼装回答生成的 system prompt，包含角色与生成规范"""
        requirements = (self.response_generation_requirements or "").replace("{count}", str(count))
        if requirements:
            return f"{self.response_system_prompt}\n\n{requirements}"
        return self.response_system_prompt
    
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
    
    async def _call_llm(self, messages: List[Dict[str, str]], response_format: str = "auto", max_tokens: int = None, count: int = 3) -> Optional[Dict[str, Any]]:
        """真实的OpenRouter API调用"""
        if not self.api_client:
            return None
        
        try:
            # 使用配置中的参数
            if max_tokens is None:
                max_tokens = settings.openrouter_max_tokens
            
            # 构建响应格式
            format_schema = None
            if response_format == "response":
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
            elif response_format == "opinion_prediction":
                format_schema = {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "opinion_prediction",
                        "schema": {
                            "type": "object",
                            "properties": {
                                "prediction": {
                                    "type": "object",
                                    "properties": {
                                        "tendency": {"type": "string", "description": "意见倾向"},
                                        "mood": {"type": "string", "description": "心情"},
                                        "tone": {"type": "string", "description": "语气"}
                                    },
                                    "required": ["tendency", "mood", "tone"]
                                }
                            },
                            "required": ["prediction"]
                        }
                    }
                }
            
            # 调用API - 使用配置中的模型和参数
            response = await self.api_client.chat.completions.create(
                model=settings.openrouter_model,
                messages=messages,
                max_tokens=max_tokens,
                temperature=settings.openrouter_temperature,
                response_format=format_schema
            )
            
            # 解析响应，兼容 response_format=json_schema 时的 message.parsed
            choice_msg = response.choices[0].message
            parsed = getattr(choice_msg, "parsed", None)
            if parsed:
                return parsed

            content = choice_msg.content
            if not content:
                logger.error(
                    "OpenRouter 返回空内容，无法解析；response_id=%s, model=%s",
                    getattr(response, "id", None),
                    getattr(response, "model", None),
                )
                return None

            try:
                return json.loads(content)
            except json.JSONDecodeError as decode_err:
                logger.error(
                    "OpenRouter 返回内容非JSON，可疑响应，截断日志: %s",
                    content[:500]
                )
                raise decode_err
            
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
