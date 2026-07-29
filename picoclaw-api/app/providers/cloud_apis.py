#!/usr/bin/env python3
"""
🦞 云端 API 提供商 —— 国产大模型统一适配
通过 OpenAI 兼容格式调用各家 API，只需配置 API Key

支持的厂商:
  - 通义千问 (阿里云 DashScope)
  - DeepSeek
  - 智谱 GLM (ChatGLM)
  - Kimi (月之暗面 Moonshot)
  - MiniMax
  - 百度文心一言
  - 讯飞星火
"""

import time
import logging
from typing import Dict, Any, AsyncGenerator

import httpx

from . import BaseProvider, ChatMessage, ChatRequest, ChatResponse, ProviderInfo

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════
# 厂商 API 配置注册表
# ═══════════════════════════════════════════════════

CLOUD_PROVIDERS: Dict[str, Dict[str, Any]] = {
    "dashscope": {
        "name": "通义千问",
        "icon": "🟠",
        "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "models": [
            "qwen-turbo",
            "qwen-plus",
            "qwen-max",
            "qwen-long",
            "qwen2.5-72b-instruct",
            "qwen2.5-32b-instruct",
            "qwen2.5-14b-instruct",
            "qwen2.5-7b-instruct",
            "qwen2.5-3b-instruct",
            "qwen2.5-1.5b-instruct",
            "qwen2.5-0.5b-instruct",
        ],
        "description": "阿里云通义千问，中文能力强，性价比高",
        "api_key_env": "DASHSCOPE_API_KEY",
        "website": "https://dashscope.console.aliyun.com/",
    },
    "deepseek": {
        "name": "DeepSeek",
        "icon": "🔵",
        "base_url": "https://api.deepseek.com/v1",
        "models": [
            "deepseek-chat",
            "deepseek-reasoner",
        ],
        "description": "DeepSeek，推理和编程能力强",
        "api_key_env": "DEEPSEEK_API_KEY",
        "website": "https://platform.deepseek.com/",
    },
    "zhipu": {
        "name": "智谱 GLM",
        "icon": "🟢",
        "base_url": "https://open.bigmodel.cn/api/paas/v4",
        "models": [
            "glm-4-flash",
            "glm-4-air",
            "glm-4-airx",
            "glm-4",
            "glm-4-plus",
            "glm-4-long",
        ],
        "description": "智谱 GLM 系列，免费额度充足",
        "api_key_env": "ZHIPU_API_KEY",
        "website": "https://open.bigmodel.cn/",
    },
    "kimi": {
        "name": "Kimi",
        "icon": "🌙",
        "base_url": "https://api.moonshot.cn/v1",
        "models": [
            "moonshot-v1-8k",
            "moonshot-v1-32k",
            "moonshot-v1-128k",
        ],
        "description": "Kimi (月之暗面)，长文本能力强",
        "api_key_env": "KIMI_API_KEY",
        "website": "https://platform.moonshot.cn/",
    },
    "minimax": {
        "name": "MiniMax",
        "icon": "🟣",
        "base_url": "https://api.minimax.chat/v1",
        "models": [
            "abab6.5s-chat",
            "abab6.5-chat",
            "abab5.5-chat",
        ],
        "description": "MiniMax，支持多轮对话",
        "api_key_env": "MINIMAX_API_KEY",
        "website": "https://platform.minimaxi.com/",
    },
    "baidu": {
        "name": "百度文心",
        "icon": "🔷",
        "base_url": "https://qianfan.baidubce.com/v2",
        "models": [
            "ernie-4.0-8k",
            "ernie-3.5-8k",
            "ernie-speed-8k",
            "ernie-speed-128k",
            "ernie-lite-8k",
        ],
        "description": "百度文心一言，中文理解优秀",
        "api_key_env": "BAIDU_API_KEY",
        "website": "https://qianfan.baidubce.com/",
    },
    "xinghuo": {
        "name": "讯飞星火",
        "icon": "⭐",
        "base_url": "https://spark-api-open.xf-yun.com/v1",
        "models": [
            "generalv3.5",
            "generalv3",
            "general",
        ],
        "description": "讯飞星火，语音交互特色",
        "api_key_env": "XINGHUO_API_KEY",
        "website": "https://xinghuo.xfyun.cn/",
    },
}


class CloudAPIProvider(BaseProvider):
    """
    云端 API 提供商 —— 通过 OpenAI 兼容格式调用
    所有国产厂商都支持 OpenAI 风格的 /chat/completions 接口
    """

    def __init__(self, provider_id: str = "", model: str = "", api_key: str = "", **kwargs):
        super().__init__(model=model, api_key=api_key, **kwargs)
        self.provider_id = provider_id
        self.config = CLOUD_PROVIDERS.get(provider_id, {})
        self.base_url = self.config.get("base_url", "")

    # ──────────────────────────────────────────────
    # 推理接口
    # ──────────────────────────────────────────────

    async def chat(self, request: ChatRequest) -> ChatResponse:
        """非流式对话"""
        start = time.time()

        payload = {
            "model": self.model,
            "messages": [{"role": m.role, "content": m.content} for m in request.messages],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens,
            "stream": False,
        }

        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                f"{self.base_url}/chat/completions",
                json=payload,
                headers=self._headers(),
            )
        resp.raise_for_status()
        data = resp.json()

        elapsed = int((time.time() - start) * 1000)
        choice = data["choices"][0]["message"]

        return ChatResponse(
            content=choice["content"],
            model=self.model,
            provider=self.provider_id,
            tokens_used=data.get("usage", {}).get("total_tokens", 0),
            duration_ms=elapsed,
        )

    async def chat_stream(self, request: ChatRequest) -> AsyncGenerator[str, None]:
        """流式对话"""
        import json

        payload = {
            "model": self.model,
            "messages": [{"role": m.role, "content": m.content} for m in request.messages],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens,
            "stream": True,
        }

        async with httpx.AsyncClient(timeout=60) as client:
            async with client.stream(
                "POST",
                f"{self.base_url}/chat/completions",
                json=payload,
                headers=self._headers(),
            ) as resp:
                async for line in resp.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:]
                        if data_str.strip() == "[DONE]":
                            return
                        try:
                            chunk = json.loads(data_str)
                            delta = chunk["choices"][0].get("delta", {})
                            if "content" in delta:
                                yield delta["content"]
                        except json.JSONDecodeError:
                            continue

    def health_check(self) -> Dict[str, Any]:
        """检查 API Key 是否配置"""
        return {
            "healthy": bool(self.api_key and self.model),
            "has_api_key": bool(self.api_key),
            "model_configured": bool(self.model),
        }

    def get_info(self) -> ProviderInfo:
        cfg = self.config
        return ProviderInfo(
            id=self.provider_id,
            name=cfg.get("name", self.provider_id),
            type="cloud",
            description=cfg.get("description", ""),
            needs_api_key=True,
            api_key_env=cfg.get("api_key_env", ""),
            models=cfg.get("models", []),
            icon=cfg.get("icon", "🔮"),
        )

    # ──────────────────────────────────────────────
    # 内部方法
    # ──────────────────────────────────────────────

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }


def get_cloud_provider_ids() -> list:
    """返回所有云端提供商 ID"""
    return list(CLOUD_PROVIDERS.keys())


def get_cloud_provider_config(provider_id: str) -> Dict[str, Any]:
    """返回指定云端提供商的配置"""
    return CLOUD_PROVIDERS.get(provider_id, {})
