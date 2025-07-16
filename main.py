from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
import io

app = FastAPI(title="荣昶杯项目 API", version="1.0.0")

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
    """
    # TODO: 在此处调用STT模型
    return STTResponse(text="暂未实现", confidence=0.0, processing_time=0.0)


@app.post("/api/tts")
async def text_to_speech(request: TTSRequest):
    """
    文字转语音 API
    
    接收文本并返回音频流
    """
    # TODO: 在此处调用TTS模型
    # 返回一个空的音频流作为占位符
    def generate_empty_audio():
        yield b""
    
    return StreamingResponse(
        generate_empty_audio(),
        media_type="audio/wav",
        headers={"Content-Disposition": "attachment; filename=output.wav"}
    )


@app.post("/api/generate_suggestions", response_model=GenerateSuggestionsResponse)
async def generate_suggestions(request: GenerateSuggestionsRequest):
    """
    生成回答建议 API
    
    根据上下文信息生成多个回答建议
    """
    # TODO: 在此处调用LLM模型
    # 根据所有输入的有效字段，动态地、智能地组合成一个结构化的Prompt
    # 解析LLM返回的结果，提取出建议列表
    
    # 暂时返回示例数据
    suggestions = [
        Suggestion(id=1, content="建议1：暂未实现", confidence=0.8),
        Suggestion(id=2, content="建议2：暂未实现", confidence=0.7),
        Suggestion(id=3, content="建议3：暂未实现", confidence=0.6)
    ]
    
    return GenerateSuggestionsResponse(
        suggestions=suggestions,
        processing_time=0.0
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)