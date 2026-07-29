<div align="center">

# 🦞 PicoClaw API

**Unified AI Gateway for Raspberry Pi — Local LLM + 7 Chinese Cloud APIs, One-Click Switch**

[English](README.md) | [中文](README.zh.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4B-red.svg)](https://www.raspberrypi.org/)
[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-green.svg)](https://fastapi.tiangolo.com)

![Web Dashboard](https://via.placeholder.com/800x400?text=PicoClaw+API+Dashboard)

</div>

---

## ✨ Features

- 🏠 **Local Inference** — Run GGUF models directly on Raspberry Pi with llama.cpp
- ☁️ **7 Chinese Cloud APIs** — DashScope, DeepSeek, Zhipu GLM, Kimi, MiniMax, Baidu, iFlytek
- 🔀 **One-Click Switch** — Ctrl+K command palette to switch providers instantly (like Claude Code's `/model`)
- 🌐 **Web Dashboard** — Beautiful dark-themed UI for chat, provider management, and monitoring
- 🔌 **Unified API** — Single `/api/chat` endpoint, auto-routes to active provider
- 📡 **Streaming Support** — SSE streaming for real-time responses
- 🛡️ **2GB RAM Optimized** — Works on Raspberry Pi 4B with as little as 2GB RAM
- 🇨🇳 **China-Friendly** — Auto-detects network, uses Chinese mirrors when needed

---

## 🚀 Quick Start

### Option 1: Direct Install (Recommended)

```bash
git clone https://github.com/YOUR_USERNAME/picoclaw-api.git
cd picoclaw-api
chmod +x install.sh
sudo bash install.sh
```

### Option 2: Windows Helper (When Pi can't access GitHub/HuggingFace)

On Windows PowerShell:
```powershell
.\download-for-pi.ps1 -PiIP 192.168.5.33
```

Then on Raspberry Pi:
```bash
sudo bash install.sh
```

### Access

After installation, open your browser:
- **Web Dashboard**: `http://<Pi_IP>:9000`
- **API Endpoint**: `http://<Pi_IP>:9000/api/chat`

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Client / Browser                      │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│              PicoClaw API Gateway (FastAPI)              │
│                      Port 9000                           │
│                                                         │
│   /api/chat        ← Unified chat endpoint              │
│   /api/providers/* ← Provider management                │
│   /                ← Web dashboard                      │
└───────────────────────┬─────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          │ Provider Manager Router    │
          │ (active_provider switch)   │
          └─────┬────────────────┬─────┘
                │                │
       ┌────────▼────────┐  ┌────▼─────────────────┐
       │   Local Engine    │  │  Cloud APIs (7)       │
       │   llama-server   │  │                        │
       │   Port 8081      │  │  🟠 DashScope (阿里)    │
       │                  │  │  🔵 DeepSeek           │
       │  GGUF Models     │  │  🟢 Zhipu GLM         │
       │  (Qwen, Llama)   │  │  🌙 Kimi              │
       │                  │  │  🟣 MiniMax           │
       │                  │  │  🔷 Baidu             │
       │                  │  │  ⭐ iFlytek           │
       └──────────────────┘  └────────────────────────┘
```

---

## 📡 API Reference

### Chat (Non-streaming)

```bash
POST /api/chat
Content-Type: application/json

{
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "temperature": 0.7,
  "max_tokens": 2048
}
```

Response:
```json
{
  "reply": "Hello! How can I help you?",
  "model": "qwen2.5-1.5b-instruct-q4_k_m.gguf",
  "provider": "local_llama",
  "tokens_used": 42,
  "duration_ms": 1200
}
```

### Chat (Streaming SSE)

```bash
POST /api/chat/stream
Content-Type: application/json

{
  "messages": [{"role": "user", "content": "Hello!"}]
}
```

### Switch Provider

```bash
POST /api/providers/switch
Content-Type: application/json

{"provider_id": "deepseek"}
```

### Configure Provider

```bash
POST /api/providers/config
Content-Type: application/json

{
  "provider_id": "deepseek",
  "api_key": "sk-xxxxxxxx",
  "model": "deepseek-chat"
}
```

### Status

```bash
GET /api/status
GET /api/health
```

---

## 🧠 Supported Models

### Local (GGUF, via llama.cpp)

| Memory | Model | Size | Chinese |
|--------|-------|------|---------|
| 2GB | Qwen2.5-1.5B-Instruct-Q4_K_M | ~1.0GB | ★★★★ |
| 2GB | TinyLlama-1.1B-Chat-Q4_K_M | ~0.6GB | ★★ |
| 4GB | Qwen2.5-3B-Instruct-Q4_K_M | ~2.0GB | ★★★★★ |
| 4GB | Phi-3-Mini-3.8B-Instruct-Q4_K_M | ~2.3GB | ★★★ |
| 8GB | Qwen2.5-7B-Instruct-Q4_K_M | ~4.7GB | ★★★★★ |

### Cloud APIs

| Provider | ID | Free Tier | Website |
|----------|-----|-----------|---------|
| DashScope (Alibaba) | `dashscope` | ✅ | [dashscope.aliyun.com](https://dashscope.console.aliyun.com/) |
| DeepSeek | `deepseek` | ✅ | [platform.deepseek.com](https://platform.deepseek.com/) |
| Zhipu GLM | `zhipu` | ✅ (generous) | [open.bigmodel.cn](https://open.bigmodel.cn/) |
| Kimi (Moonshot) | `kimi` | ✅ | [platform.moonshot.cn](https://platform.moonshot.cn/) |
| MiniMax | `minimax` | ✅ | [platform.minimaxi.com](https://platform.minimaxi.com/) |
| Baidu ERNIE | `baidu` | ✅ | [qianfan.baidubce.com](https://qianfan.baidubce.com/) |
| iFlytek Spark | `xinghuo` | ✅ | [xinghuo.xfyun.cn](https://xinghuo.xfyun.cn/) |

---

## 🔧 Commands

```bash
# Services
sudo systemctl status picoclaw-api     # Check status
sudo systemctl restart picoclaw-api     # Restart
journalctl -u picoclaw-api -f          # View logs

# Environment variables (optional)
API_PORT=9000          # API port (default: 9000)
LLAMA_PORT=8081        # llama-server port (default: 8081)
CTX_SIZE=2048          # Context size (default: 2048)
THREADS=4              # CPU threads (default: 4)
```

---

## 📝 System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| Device | Raspberry Pi 4B (2GB) | Raspberry Pi 4B (4GB/8GB) |
| OS | Raspberry Pi OS 64-bit | Debian 12 (Bookworm) 64-bit |
| Storage | 16GB SD card | 32GB+ SD card / SSD |
| Network | WiFi | Wired Ethernet |
| Cooling | Heatsink | Active fan ⭐ |
| Power | 5V/2A | 5V/3A (official) |

---

## ⚠️ Important Notes

1. **64-bit OS required** — Large models need >4GB address space
2. **Active cooling is mandatory** — CPU runs at 100% during inference
3. **SSD recommended** — SD cards are slow for model loading
4. **First boot is slow** — Model loading takes 30s~2min
5. **Cloud APIs need internet** — Local models work offline
6. **2GB RAM users** — Use 1-3B small models, or use cloud APIs

---

## ❓ Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions to common issues.

Quick fixes:

```bash
# Service not starting?
sudo journalctl -u picoclaw-api --no-pager -n 20

# 500 Internal Server Error?
sudo systemctl restart picoclaw-api

# Model not loading?
sudo systemctl restart llama-server

# Port already in use?
sudo lsof -i :9000
sudo kill <PID>
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **llama.cpp model guide**: https://huggingface.co/models?tag=gguf
- **ModelScope (魔搭)**: https://modelscope.cn/
- **FastAPI**: https://fastapi.tiangolo.com/

---

<div align="center">

**🦞 Made with ❤️ for the Raspberry Pi community**

If this project helps you, please give it a ⭐!

</div>
