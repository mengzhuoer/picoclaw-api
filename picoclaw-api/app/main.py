#!/usr/bin/env python3
"""
🦞 PicoClaw API — 统一 AI 网关
================
本地推理 + 国产云端 API，一个接口搞定。
支持提供商热切换，适配树莓派 4B (2GB)。
"""

import os
import logging
from contextlib import asynccontextmanager
from typing import List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, StreamingResponse
from pydantic import BaseModel, Field

from provider_manager import ProviderManager
from providers.cloud_apis import CLOUD_PROVIDERS

# ──────────────────────────────────────────────
# 配置
# ──────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("picoclaw-api")

API_PORT = int(os.getenv("API_PORT", "9000"))
CONFIG_PATH = os.getenv("CONFIG_PATH", "/etc/picoclaw-api/providers.json")

# ──────────────────────────────────────────────
# 全局管理器
# ──────────────────────────────────────────────

manager = ProviderManager(config_path=CONFIG_PATH)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """启动时初始化提供商"""
    manager.initialize()
    # 尝试启动当前活跃的本地提供商
    provider = manager.get_active_provider()
    if provider and manager.active_id == "local_llama":
        cfg = manager._configs.get("local_llama", {})
        if cfg.get("model"):
            logger.info(f"自动加载本地模型: {cfg['model']}")
            provider.start()
    yield
    # 关闭时停止本地推理
    local = manager.get_provider("local_llama")
    if local:
        local.stop()


# ──────────────────────────────────────────────
# FastAPI 应用
# ──────────────────────────────────────────────

app = FastAPI(
    title="🦞 PicoClaw API",
    description="树莓派本地 + 云端 AI 统一网关",
    version="2.0.0",
    lifespan=lifespan,
)

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
app.mount("/static", StaticFiles(directory=f"{BASE_DIR}/static"), name="static")
templates = Jinja2Templates(directory=f"{BASE_DIR}/templates")


# ──────────────────────────────────────────────
# 请求/响应模型
# ──────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str = Field(..., description="user / assistant / system")
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    temperature: float = Field(0.7, ge=0.0, le=2.0)
    max_tokens: int = Field(2048, ge=1, le=8192)
    stream: bool = False


class ChatResponse(BaseModel):
    reply: str
    model: str
    provider: str
    tokens_used: int
    duration_ms: int


class ConfigRequest(BaseModel):
    provider_id: str
    model: str = ""
    api_key: str = ""


class SwitchRequest(BaseModel):
    provider_id: str


# ──────────────────────────────────────────────
# Web 面板
# ──────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def web_panel(request: Request):
    # 兼容新旧版本 Starlette 的 TemplateResponse
    try:
        return templates.TemplateResponse(request, "index.html")
    except TypeError:
        return templates.TemplateResponse("index.html", {"request": request})


# ──────────────────────────────────────────────
# API — 状态与提供商管理
# ──────────────────────────────────────────────

@app.get("/api/status")
async def get_status():
    """获取所有提供商状态"""
    return {
        "active_provider": manager.active_id,
        "providers": manager.list_providers(),
        "local_models": manager.list_local_models(),
        "cloud_provider_ids": list(CLOUD_PROVIDERS.keys()),
    }


@app.get("/api/providers")
async def list_providers():
    """列出所有提供商"""
    return {"providers": manager.list_providers()}


@app.get("/api/providers/cloud")
async def list_cloud_providers():
    """列出所有可用的云端提供商（含注册网址）"""
    result = {}
    for pid, cfg in CLOUD_PROVIDERS.items():
        result[pid] = {
            "name": cfg["name"],
            "icon": cfg["icon"],
            "description": cfg["description"],
            "models": cfg["models"],
            "website": cfg["website"],
            "api_key_env": cfg["api_key_env"],
        }
    return result


@app.post("/api/providers/switch")
async def switch_provider(req: SwitchRequest):
    """切换到指定提供商"""
    result = manager.switch_provider(req.provider_id)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    return result


@app.post("/api/providers/config")
async def update_config(req: ConfigRequest):
    """更新提供商配置（模型、API Key）"""
    result = manager.update_config(req.provider_id, req.model, req.api_key)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    return result


@app.post("/api/providers/add")
async def add_provider(req: ConfigRequest):
    """添加云端提供商"""
    result = manager.add_cloud_provider(req.provider_id, req.api_key, req.model)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    return result


@app.post("/api/providers/remove")
async def remove_provider(req: SwitchRequest):
    """移除云端提供商"""
    result = manager.remove_provider(req.provider_id)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    return result


# ──────────────────────────────────────────────
# API — 对话推理
# ──────────────────────────────────────────────

@app.post("/api/chat")
async def chat(req: ChatRequest):
    """非流式对话"""
    provider = manager.get_active_provider()
    if not provider:
        raise HTTPException(status_code=503, detail="没有可用的提供商，请先配置")

    from providers import ChatRequest as InternalRequest
    internal_req = InternalRequest(
        messages=req.messages,
        temperature=req.temperature,
        max_tokens=req.max_tokens,
    )

    try:
        resp = await provider.chat(internal_req)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"推理失败: {e}")

    return ChatResponse(
        reply=resp.content,
        model=resp.model,
        provider=resp.provider,
        tokens_used=resp.tokens_used,
        duration_ms=resp.duration_ms,
    )


@app.post("/api/chat/stream")
async def chat_stream(req: ChatRequest):
    """流式对话 (SSE)"""
    provider = manager.get_active_provider()
    if not provider:
        raise HTTPException(status_code=503, detail="没有可用的提供商")

    from providers import ChatRequest as InternalRequest
    internal_req = InternalRequest(
        messages=req.messages,
        temperature=req.temperature,
        max_tokens=req.max_tokens,
        stream=True,
    )

    async def event_generator():
        try:
            async for chunk in provider.chat_stream(internal_req):
                yield f"data: {chunk}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            yield f"data: [ERROR] {e}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@app.get("/api/health")
async def health():
    """健康检查"""
    provider = manager.get_active_provider()
    if not provider:
        return {"status": "no_provider"}
    health = provider.health_check()
    return {"status": "ok" if health.get("healthy") else "degraded", **health}


# ──────────────────────────────────────────────
# 入口
# ──────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=API_PORT, log_level="info")
