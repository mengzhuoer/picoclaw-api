<div align="center">

# 🦞 PicoClaw API

**树莓派统一 AI 网关 — 本地大模型 + 7 家国产云端 API，一键切换**

[English](README.md) | [中文](README.zh.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4B-red.svg)](https://www.raspberrypi.org/)
[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-green.svg)](https://fastapi.tiangolo.com)

</div>

---

## ✨ 特性

- 🏠 **本地推理** — 基于 llama.cpp，在树莓派上直接运行 GGUF 模型
- ☁️ **7 家国产 API** — 通义千问、DeepSeek、智谱 GLM、Kimi、MiniMax、百度、讯飞
- 🔀 **一键切换** — Ctrl+K 命令面板，类似 Claude Code 的 `/model` 切换
- 🌐 **Web 管理面板** — 暗色主题，支持对话测试、提供商管理、状态监控
- 📡 **流式输出** — 支持 SSE 流式对话
- 🛡️ **2GB 内存优化** — 2GB 树莓派 4B 也能流畅运行
- 🇨🇳 **国内友好** — 自动检测网络，智能使用国内镜像

---

## 🚀 快速开始

### 方式一：树莓派直接安装（推荐，网络通畅时）

```bash
git clone https://github.com/YOUR_USERNAME/picoclaw-api.git
cd picoclaw-api
chmod +x install.sh
sudo bash install.sh
```

### 方式二：Windows 辅助安装（树莓派网络受限时）

在 Windows PowerShell 中运行：
```powershell
.\download-for-pi.ps1 -PiIP 192.168.5.33
```

然后在树莓派上：
```bash
sudo bash install.sh
```

### 访问

安装完成后，打开浏览器：
- **Web 管理面板**：`http://<树莓派IP>:9000`
- **API 对话接口**：`http://<树莓派IP>:9000/api/chat`

---

## 🏗️ 架构

```
┌─────────────────────────────────────────────────────────┐
│                    客户端 / 浏览器                        │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│              PicoClaw API 网关 (FastAPI)                 │
│                     端口 9000                            │
│                                                         │
│   /api/chat        ← 统一对话接口（自动路由）             │
│   /api/providers/* ← 提供商管理（配置/切换/添加/移除）     │
│   /                ← Web 管理面板                        │
└───────────────────────┬─────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          │   Provider Manager 路由器   │
          │   (active_provider 切换)   │
          └─────┬────────────────┬─────┘
                │                │
       ┌────────▼────────┐  ┌────▼─────────────────┐
       │   本地推理引擎     │  │    云端 API（7家）     │
       │   llama-server  │  │                        │
       │   端口 8081      │  │  🟠 通义千问（阿里）    │
       │                 │  │  🔵 DeepSeek           │
       │   GGUF 模型      │  │  🟢 智谱 GLM          │
       │   (Qwen, Llama) │  │  🌙 Kimi（月之暗面）   │
       │                 │  │  🟣 MiniMax           │
       │                 │  │  🔷 百度文心           │
       │                 │  │  ⭐ 讯飞星火           │
       └─────────────────┘  └────────────────────────┘
```

---

## 📡 API 文档

### 对话（非流式）

```bash
POST /api/chat
Content-Type: application/json

{
  "messages": [
    {"role": "user", "content": "你好！"}
  ],
  "temperature": 0.7,
  "max_tokens": 2048
}
```

响应：
```json
{
  "reply": "你好！有什么可以帮助你的吗？",
  "model": "qwen2.5-1.5b-instruct-q4_k_m.gguf",
  "provider": "local_llama",
  "tokens_used": 42,
  "duration_ms": 1200
}
```

### 对话（流式 SSE）

```bash
POST /api/chat/stream
Content-Type: application/json

{
  "messages": [{"role": "user", "content": "你好！"}]
}
```

### 切换提供商

```bash
POST /api/providers/switch
Content-Type: application/json

{"provider_id": "deepseek"}
```

### 配置提供商

```bash
POST /api/providers/config
Content-Type: application/json

{
  "provider_id": "deepseek",
  "api_key": "sk-xxxxxxxx",
  "model": "deepseek-chat"
}
```

### 状态查询

```bash
GET /api/status
GET /api/health
```

---

## 🧠 支持的模型

### 本地模型（GGUF，通过 llama.cpp）

| 内存 | 推荐模型 | 大小 | 中文能力 |
|------|---------|------|---------|
| 2GB | Qwen2.5-1.5B-Instruct-Q4_K_M | ~1.0GB | ★★★★ |
| 2GB | TinyLlama-1.1B-Chat-Q4_K_M | ~0.6GB | ★★ |
| 4GB | Qwen2.5-3B-Instruct-Q4_K_M | ~2.0GB | ★★★★★ |
| 4GB | Phi-3-Mini-3.8B-Instruct-Q4_K_M | ~2.3GB | ★★★ |
| 8GB | Qwen2.5-7B-Instruct-Q4_K_M | ~4.7GB | ★★★★★ |

### 云端 API

| 厂商 | ID | 免费额度 | 申请地址 |
|------|-----|---------|---------|
| 通义千问（阿里） | `dashscope` | ✅ | [dashscope.aliyun.com](https://dashscope.console.aliyun.com/) |
| DeepSeek | `deepseek` | ✅ | [platform.deepseek.com](https://platform.deepseek.com/) |
| 智谱 GLM | `zhipu` | ✅（无限） | [open.bigmodel.cn](https://open.bigmodel.cn/) |
| Kimi（月之暗面） | `kimi` | ✅ | [platform.moonshot.cn](https://platform.moonshot.cn/) |
| MiniMax | `minimax` | ✅ | [platform.minimaxi.com](https://platform.minimaxi.com/) |
| 百度文心 | `baidu` | ✅ | [qianfan.baidubce.com](https://qianfan.baidubce.com/) |
| 讯飞星火 | `xinghuo` | ✅ | [xinghuo.xfyun.cn](https://xinghuo.xfyun.cn/) |

---

## 🔧 常用命令

```bash
# 服务管理
sudo systemctl status picoclaw-api     # 查看状态
sudo systemctl restart picoclaw-api     # 重启服务
journalctl -u picoclaw-api -f          # 查看实时日志

# 环境变量（可选）
API_PORT=9000          # API 端口（默认 9000）
LLAMA_PORT=8081        # llama-server 端口（默认 8081）
CTX_SIZE=2048          # 上下文长度（默认 2048）
THREADS=4              # CPU 线程数（默认 4）
```

---

## 📝 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| 设备 | 树莓派4B (2GB) | 树莓派4B (4GB/8GB) |
| 系统 | Raspberry Pi OS 64-bit | Debian 12 (Bookworm) 64-bit |
| 存储 | 16GB SD卡 | 32GB+ SD卡 / SSD |
| 网络 | WiFi | 有线以太网 |
| 散热 | 散热片 | 风扇主动散热 ⭐ |
| 电源 | 5V/2A | 5V/3A（官方电源） |

---

## ⚠️ 注意事项

1. **务必使用 64 位系统** — 大模型需要 >4GB 地址空间
2. **主动散热必须** — 推理时 CPU 满载，过热会降频
3. **建议使用 SSD** — SD 卡读写慢，影响模型加载速度
4. **首次启动较慢** — 模型加载到内存需要 30s~2min
5. **云端 API 需要网络** — 本地模型无需网络，断网时自动使用本地
6. **2GB RAM 建议** — 本地用 1-3B 小模型，复杂任务用云端 API 补强

---

## ❓ 问题排查

详细问题排查请查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。

快速修复：

```bash
# 服务无法启动？
sudo journalctl -u picoclaw-api --no-pager -n 20

# 500 Internal Server Error？
sudo systemctl restart picoclaw-api

# 模型加载失败？
sudo systemctl restart llama-server

# 端口被占用？
sudo lsof -i :9000
sudo kill <PID>
```

---

## 🤝 贡献

欢迎贡献代码！请按照以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

---

## 📜 许可证

本项目基于 MIT 许可证开源 — 查看 [LICENSE](LICENSE) 文件了解详情。

---

## 🔗 相关链接

- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **HuggingFace GGUF 模型**: https://huggingface.co/models?tag=gguf
- **ModelScope（魔搭）**: https://modelscope.cn/
- **FastAPI**: https://fastapi.tiangolo.com/

---

<div align="center">

**🦞 为树莓派社区打造**

如果这个项目对你有帮助，请给一个 ⭐！

</div>
