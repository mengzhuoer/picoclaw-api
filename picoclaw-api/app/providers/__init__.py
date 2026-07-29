"""
🦞 Provider 抽象层
统一本地推理引擎和云端 API 的调用接口
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional, AsyncGenerator
from dataclasses import dataclass, field


@dataclass
class ChatMessage:
    role: str  # user / assistant / system
    content: str


@dataclass
class ChatRequest:
    messages: List[ChatMessage]
    temperature: float = 0.7
    max_tokens: int = 2048
    stream: bool = False


@dataclass
class ChatResponse:
    content: str
    model: str
    provider: str
    tokens_used: int = 0
    duration_ms: int = 0


@dataclass
class ProviderInfo:
    """提供商元数据"""
    id: str                          # 唯一标识: local_llama, dashscope, deepseek, ...
    name: str                        # 显示名: 本地llama.cpp, 通义千问, DeepSeek, ...
    type: str                        # local / cloud
    description: str = ""
    needs_api_key: bool = False
    api_key_env: str = ""            # 环境变量名
    models: List[str] = field(default_factory=list)  # 支持的模型列表
    icon: str = "🔮"                 # 显示图标


class BaseProvider(ABC):
    """所有提供商的基类"""

    def __init__(self, model: str = "", api_key: str = "", **kwargs):
        self.model = model
        self.api_key = api_key
        self.extra_config = kwargs

    @abstractmethod
    async def chat(self, request: ChatRequest) -> ChatResponse:
        """非流式对话"""
        ...

    @abstractmethod
    async def chat_stream(self, request: ChatRequest) -> AsyncGenerator[str, None]:
        """流式对话，逐 token 返回"""
        ...

    @abstractmethod
    def health_check(self) -> Dict[str, Any]:
        """健康检查，返回状态信息"""
        ...

    def get_info(self) -> ProviderInfo:
        """返回提供商信息"""
        raise NotImplementedError
