# 🧠 模型选择指南

## 树莓派4 模型推荐

### 根据内存选择

| 你的内存 | 推荐模型 | 下载大小 | 推理速度 | 中文能力 |
|---------|---------|---------|---------|---------|
| **2GB** | TinyLlama 1.1B | 637MB | ⚡⚡⚡ 快 | ⭐⭐ 一般 |
| **2GB** | Qwen2.5 1.5B | 1.0GB | ⚡⚡ 较快 | ⭐⭐⭐⭐ 好 |
| **4GB** | **Phi-3-Mini 3.8B** ⭐ | 2.3GB | ⚡⚡ 较快 | ⭐⭐⭐ 不错 |
| **4GB** | Llama 3.2 3B | 2.0GB | ⚡⚡ 较快 | ⭐⭐⭐ 不错 |
| **4GB** | Qwen2.5 3B | 2.0GB | ⚡⚡ 较快 | ⭐⭐⭐⭐⭐ 优秀 |
| **8GB** | Llama 3.1 8B | 4.9GB | ⚡ 中等 | ⭐⭐⭐⭐ 好 |
| **8GB** | Qwen2.5 7B | 4.7GB | ⚡ 中等 | ⭐⭐⭐⭐⭐ 优秀 |

---

## 模型下载方式

### 方式一：通过 Ollama (OpenClaw)

```bash
# 搜索模型
ollama search llama

# 下载模型
ollama pull llama3.2:3b
ollama pull phi3:3.8b
ollama pull qwen2.5:3b

# 查看已下载
ollama list

# 删除模型
ollama rm llama3.2:3b
```

### 方式二：手动下载 GGUF (PicoClaw)

```bash
# 创建模型目录
mkdir -p /var/lib/picoclaw/models
cd /var/lib/picoclaw/models

# 从 HuggingFace 下载
wget https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct.Q4_K_M.gguf

# 或使用 hf-cli
pip install huggingface-hub
huggingface-cli download bartowski/Llama-3.2-3B-Instruct-GGUF Llama-3.2-3B-Instruct.Q4_K_M.gguf --local-dir /var/lib/picoclaw/models/
```

---

## 量化级别说明

| 量化 | 质量 | 速度 | 大小 | 推荐场景 |
|------|------|------|------|---------|
| Q2_K | ⭐ | ⚡⚡⚡⚡ | 最小 | 不推荐 |
| Q3_K_M | ⭐⭐ | ⚡⚡⚡ | 小 | 极低内存 |
| **Q4_K_M** ⭐ | ⭐⭐⭐ | ⚡⚡ | 中等 | **最佳平衡** |
| Q5_K_M | ⭐⭐⭐⭐ | ⚡ | 较大 | 高质量 |
| Q6_K | ⭐⭐⭐⭐⭐ | 🐢 慢 | 大 | 接近原始 |
| Q8_0 | ⭐⭐⭐⭐⭐ | 🐢 慢 | 很大 | 不推荐 RPi |

> **推荐**: 树莓派4 使用 `Q4_K_M` 量化，在质量和速度间取得最佳平衡。

---

## 中文能力排行

1. **Qwen 系列** (阿里通义千问) —— 中文最强
2. **Llama 3.x** (Meta) —— 多语言均衡
3. **Phi-3** (微软) —— 英文优秀，中文可用
4. **Mistral** —— 英文为主
5. **TinyLlama** —— 基础对话

---

## 切换模型

### PicoClaw 切换模型

```bash
# 1. 下载新模型
cd /var/lib/picoclaw/models
wget <新模型URL>

# 2. 修改配置
sudo nano /etc/picoclaw/config.yaml
# 修改: llm.model: /var/lib/picoclaw/models/新模型.gguf

# 3. 重启服务
sudo systemctl restart llama-server
sudo systemctl restart picoclaw
```

### OpenClaw 切换模型

```bash
# 1. 下载新模型
ollama pull qwen2.5:7b

# 2. 修改配置
sudo nano /etc/openclaw/config.yaml
# 修改: llm.model: qwen2.5:7b

# 3. 重启服务
sudo systemctl restart openclaw
```

---

## 性能优化建议

1. **使用 SSD** —— 模型加载速度提升 5-10x
2. **超频树莓派** —— `config.txt` 中设置 `over_voltage=4`, `arm_freq=1800`
3. **限制上下文长度** —— 减少 `context_length` 到 2048
4. **关闭不必要的服务** —— 释放内存给模型
5. **使用 zram** —— 压缩内存，等效增加可用内存

```bash
# 启用 zram
sudo apt install zram-tools
echo "ALGO=lz4" | sudo tee /etc/default/zramswap
echo "PERCENT=50" | sudo tee -a /etc/default/zramswap
sudo systemctl restart zramswap
```
