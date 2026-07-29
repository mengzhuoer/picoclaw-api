#!/usr/bin/env python3
"""
🦞 本地 llama.cpp 提供商
通过 llama-server 进行本地推理
"""

import os
import time
import subprocess
import signal
import logging
from pathlib import Path
from typing import Dict, Any, AsyncGenerator

import httpx
import requests

from . import BaseProvider, ChatMessage, ChatRequest, ChatResponse, ProviderInfo

logger = logging.getLogger(__name__)


class LocalLlamaProvider(BaseProvider):
    """本地 llama.cpp 推理引擎"""

    def __init__(
        self,
        model: str = "",
        api_key: str = "",
        llama_bin: str = "/opt/llama.cpp/build/bin/llama-server",
        model_dir: str = "/var/lib/picoclaw/models",
        port: int = 8081,
        host: str = "127.0.0.1",
        ctx_size: int = 2048,
        threads: int = 4,
        **kwargs,
    ):
        super().__init__(model=model, api_key=api_key, **kwargs)
        self.llama_bin = llama_bin
        self.model_dir = Path(model_dir)
        self.port = port
        self.host = host
        self.ctx_size = ctx_size
        self.threads = threads
        self._process = None

    # ──────────────────────────────────────────────
    # 进程管理
    # ──────────────────────────────────────────────

    def start(self) -> bool:
        """启动 llama-server"""
        self.stop()

        model_path = self.model_dir / self.model
        if not model_path.exists():
            raise FileNotFoundError(f"模型不存在: {model_path}")

        cmd = [
            self.llama_bin,
            "-m", str(model_path),
            "--port", str(self.port),
            "--host", self.host,
            "--ctx-size", str(self.ctx_size),
            "--threads", str(self.threads),
            "--n-gpu-layers", "0",
        ]

        logger.info(f"启动 llama-server: {self.model}")
        self._process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            preexec_fn=os.setsid,
        )

        return self._wait_ready()

    def stop(self):
        """停止 llama-server"""
        if self._process and self._process.poll() is None:
            try:
                os.killpg(os.getpgid(self._process.pid), signal.SIGTERM)
                self._process.wait(timeout=10)
            except (subprocess.TimeoutExpired, ProcessLookupError):
                os.killpg(os.getpgid(self._process.pid), signal.SIGKILL)
                self._process.wait(timeout=5)
        self._process = None

    @property
    def is_running(self) -> bool:
        return self._process is not None and self._process.poll() is None

    # ──────────────────────────────────────────────
    # 推理接口
    # ──────────────────────────────────────────────

    async def chat(self, request: ChatRequest) -> ChatResponse:
        """非流式对话"""
        start = time.time()

        payload = {
            "messages": [{"role": m.role, "content": m.content} for m in request.messages],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens,
            "stream": False,
        }

        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                f"http://{self.host}:{self.port}/v1/chat/completions",
                json=payload,
            )
        resp.raise_for_status()
        data = resp.json()

        elapsed = int((time.time() - start) * 1000)
        choice = data["choices"][0]["message"]

        return ChatResponse(
            content=choice["content"],
            model=self.model,
            provider="local_llama",
            tokens_used=data.get("usage", {}).get("total_tokens", 0),
            duration_ms=elapsed,
        )

    async def chat_stream(self, request: ChatRequest) -> AsyncGenerator[str, None]:
        """流式对话"""
        import json

        payload = {
            "messages": [{"role": m.role, "content": m.content} for m in request.messages],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens,
            "stream": True,
        }

        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream(
                "POST",
                f"http://{self.host}:{self.port}/v1/chat/completions",
                json=payload,
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
        try:
            r = requests.get(f"http://{self.host}:{self.port}/health", timeout=2)
            return {"healthy": r.status_code == 200, "running": self.is_running}
        except Exception:
            return {"healthy": False, "running": self.is_running}

    def get_info(self) -> ProviderInfo:
        return ProviderInfo(
            id="local_llama",
            name="本地 llama.cpp",
            type="local",
            description="本地运行 GGUF 模型，无需网络，隐私安全",
            needs_api_key=False,
            icon="🏠",
        )

    # ──────────────────────────────────────────────
    # 内部方法
    # ──────────────────────────────────────────────

    def _wait_ready(self, timeout: int = 120) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if not self.is_running:
                return False
            try:
                r = requests.get(
                    f"http://{self.host}:{self.port}/health", timeout=1
                )
                if r.status_code == 200:
                    return True
            except Exception:
                pass
            time.sleep(1)
        return False
