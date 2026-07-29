#!/usr/bin/env python3
"""
🦞 Provider Manager — 统一管理所有本地和云端 AI 提供商
负责：注册、切换、配置持久化、健康检查
"""

import os
import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional, List

from providers import BaseProvider, ChatRequest, ChatResponse, ChatMessage, ProviderInfo
from providers.local_llama import LocalLlamaProvider
from providers.cloud_apis import CloudAPIProvider, CLOUD_PROVIDERS

logger = logging.getLogger(__name__)


class ProviderManager:
    """
    提供商管理器
    - 管理所有已注册的提供商实例
    - 维护当前活跃提供商
    - 持久化配置到 JSON 文件
    """

    def __init__(self, config_path: str = "/etc/picoclaw-api/providers.json"):
        self.config_path = Path(config_path)
        self._providers: Dict[str, BaseProvider] = {}
        self._active_id: Optional[str] = None
        self._configs: Dict[str, Dict[str, Any]] = {}

        # 加载已保存的配置
        self._load_config()

    # ──────────────────────────────────────────────
    # 初始化与注册
    # ──────────────────────────────────────────────

    def initialize(self):
        """
        初始化所有提供商。
        从保存的配置中恢复，如果没有则注册默认本地提供商。
        """
        if not self._configs:
            # 首次运行：注册本地提供商
            logger.info("首次运行，注册默认本地提供商")
            self._configs["local_llama"] = {
                "model": "",
                "api_key": "",
                "enabled": True,
            }

        # 实例化本地提供商
        if "local_llama" in self._configs:
            cfg = self._configs["local_llama"]
            self._providers["local_llama"] = LocalLlamaProvider(
                model=cfg.get("model", ""),
                llama_bin=os.getenv("LLAMA_BIN", "/opt/llama.cpp/build/bin/llama-server"),
                model_dir=os.getenv("MODEL_DIR", "/var/lib/picocaw/models"),
                port=int(os.getenv("LLAMA_PORT", "8081")),
                ctx_size=int(os.getenv("CTX_SIZE", "2048")),
                threads=int(os.getenv("THREADS", "4")),
            )

        # 实例化云端提供商
        for provider_id, cfg in self._configs.items():
            if provider_id == "local_llama":
                continue
            if provider_id in CLOUD_PROVIDERS:
                self._providers[provider_id] = CloudAPIProvider(
                    provider_id=provider_id,
                    model=cfg.get("model", ""),
                    api_key=cfg.get("api_key", ""),
                )

        # 恢复上次活跃的提供商
        active = self._configs.get("_active", None)
        if active and active in self._providers:
            self._active_id = active
        elif self._providers:
            self._active_id = list(self._providers.keys())[0]

        logger.info(f"已注册 {len(self._providers)} 个提供商，当前活跃: {self._active_id}")

    # ──────────────────────────────────────────────
    # 提供商操作
    # ──────────────────────────────────────────────

    def list_providers(self) -> List[Dict[str, Any]]:
        """列出所有提供商及其状态"""
        result = []
        for pid, provider in self._providers.items():
            info = provider.get_info()
            health = provider.health_check()
            cfg = self._configs.get(pid, {})
            result.append({
                "id": pid,
                "name": info.name,
                "icon": info.icon,
                "type": info.type,
                "description": info.description,
                "needs_api_key": info.needs_api_key,
                "has_api_key": bool(cfg.get("api_key")),
                "model": cfg.get("model", ""),
                "models": info.models,
                "enabled": cfg.get("enabled", True),
                "is_active": pid == self._active_id,
                "health": health,
            })
        return result

    def get_provider(self, provider_id: str) -> Optional[BaseProvider]:
        """获取指定提供商实例"""
        return self._providers.get(provider_id)

    def get_active_provider(self) -> Optional[BaseProvider]:
        """获取当前活跃的提供商"""
        if self._active_id:
            return self._providers.get(self._active_id)
        return None

    @property
    def active_id(self) -> Optional[str]:
        return self._active_id

    def switch_provider(self, provider_id: str) -> Dict[str, Any]:
        """
        切换到指定提供商。
        本地提供商需要启动 llama-server，云端提供商只需验证配置。
        """
        if provider_id not in self._providers:
            return {"success": False, "message": f"未知提供商: {provider_id}"}

        provider = self._providers[provider_id]
        cfg = self._configs.get(provider_id, {})

        # 检查是否已配置
        info = provider.get_info()
        if info.needs_api_key and not cfg.get("api_key"):
            return {
                "success": False,
                "message": f"请先配置 {info.name} 的 API Key",
            }

        if not cfg.get("model"):
            return {
                "success": False,
                "message": f"请为 {info.name} 选择模型",
            }

        # 本地提供商：启动 llama-server
        if provider_id == "local_llama":
            if not cfg.get("model"):
                return {"success": False, "message": "请先选择本地模型文件"}
            try:
                provider.model = cfg["model"]
                if not provider.start():
                    return {"success": False, "message": "本地模型加载失败，请检查模型文件"}
            except FileNotFoundError as e:
                return {"success": False, "message": str(e)}
            except Exception as e:
                return {"success": False, "message": f"启动失败: {e}"}

        # 切换活跃提供商
        old_id = self._active_id
        self._active_id = provider_id
        self._configs["_active"] = provider_id
        self._save_config()

        return {
            "success": True,
            "message": f"已切换到 {info.name} ({cfg['model']})",
            "provider_id": provider_id,
            "model": cfg["model"],
        }

    # ──────────────────────────────────────────────
    # 配置管理
    # ──────────────────────────────────────────────

    def update_config(self, provider_id: str, model: str = "", api_key: str = "") -> Dict[str, Any]:
        """更新提供商配置"""
        if provider_id not in self._configs:
            # 新云端提供商
            if provider_id not in CLOUD_PROVIDERS:
                return {"success": False, "message": f"未知提供商: {provider_id}"}
            self._configs[provider_id] = {"model": "", "api_key": "", "enabled": True}

        if model:
            self._configs[provider_id]["model"] = model
        if api_key:
            self._configs[provider_id]["api_key"] = api_key

        # 重新实例化
        if provider_id == "local_llama":
            cfg = self._configs[provider_id]
            self._providers[provider_id] = LocalLlamaProvider(
                model=cfg.get("model", ""),
                llama_bin=os.getenv("LLAMA_BIN", "/opt/llama.cpp/build/bin/llama-server"),
                model_dir=os.getenv("MODEL_DIR", "/var/lib/picoclaw/models"),
                port=int(os.getenv("LLAMA_PORT", "8081")),
            )
        else:
            cfg = self._configs[provider_id]
            self._providers[provider_id] = CloudAPIProvider(
                provider_id=provider_id,
                model=cfg.get("model", ""),
                api_key=cfg.get("api_key", ""),
            )

        self._save_config()
        return {"success": True, "message": "配置已更新"}

    def add_cloud_provider(self, provider_id: str, api_key: str, model: str = "") -> Dict[str, Any]:
        """添加云端提供商"""
        if provider_id not in CLOUD_PROVIDERS:
            return {"success": False, "message": f"不支持的提供商: {provider_id}"}

        cfg = CLOUD_PROVIDERS[provider_id]
        if not model and cfg.get("models"):
            model = cfg["models"][0]  # 默认选第一个模型

        self._configs[provider_id] = {
            "model": model,
            "api_key": api_key,
            "enabled": True,
        }

        self._providers[provider_id] = CloudAPIProvider(
            provider_id=provider_id,
            model=model,
            api_key=api_key,
        )

        self._save_config()
        return {"success": True, "message": f"已添加 {cfg['name']}"}

    def remove_provider(self, provider_id: str) -> Dict[str, Any]:
        """移除云端提供商"""
        if provider_id == "local_llama":
            return {"success": False, "message": "不能移除本地提供商"}

        if provider_id in self._providers:
            del self._providers[provider_id]
        if provider_id in self._configs:
            del self._configs[provider_id]

        if self._active_id == provider_id:
            self._active_id = "local_llama" if "local_llama" in self._providers else None
            self._configs["_active"] = self._active_id

        self._save_config()
        return {"success": True, "message": "已移除"}

    # ──────────────────────────────────────────────
    # 模型文件管理
    # ──────────────────────────────────────────────

    def list_local_models(self) -> List[Dict[str, Any]]:
        """列出本地模型目录中的 GGUF 文件"""
        model_dir = Path(os.getenv("MODEL_DIR", "/var/lib/picoclaw/models"))
        models = []
        if model_dir.exists():
            for f in sorted(model_dir.iterdir()):
                if f.suffix == ".gguf":
                    size = f.stat().st_size
                    models.append({
                        "name": f.name,
                        "size_mb": round(size / (1024 * 1024), 1),
                        "size_human": self._human_size(size),
                    })
        return models

    # ──────────────────────────────────────────────
    # 持久化
    # ──────────────────────────────────────────────

    def _load_config(self):
        """从 JSON 文件加载配置"""
        if self.config_path.exists():
            try:
                with open(self.config_path) as f:
                    self._configs = json.load(f)
                logger.info(f"已加载配置: {self.config_path}")
            except Exception as e:
                logger.warning(f"加载配置失败: {e}")
                self._configs = {}

    def _save_config(self):
        """保存配置到 JSON 文件"""
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.config_path, "w") as f:
            json.dump(self._configs, f, ensure_ascii=False, indent=2)

    @staticmethod
    def _human_size(size: int) -> str:
        for unit in ("B", "KB", "MB", "GB"):
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"
