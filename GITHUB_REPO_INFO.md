# 📦 GitHub 仓库信息

## 仓库名称

**picoclaw-api**

## 简短描述（Repository Description）

```
🦞 Unified AI Gateway for Raspberry Pi — Run local GGUF models + 7 Chinese cloud APIs with one-click switching. 2GB RAM optimized, China-friendly mirrors built-in.
```

中文版本：
```
🦞 树莓派统一 AI 网关 — 本地 GGUF 模型 + 7 家国产云端 API，一键切换。2GB 内存优化，内置国内镜像。
```

## Topics（标签）

```
raspberry-pi, llama-cpp, llm, local-ai, fastapi, python, ai-gateway, 
gguf, qwen, deepseek, zhipu, kimi, dashscope, inference, edge-computing,
chinese-llm, unified-api, one-click-switch
```

中文标签：
```
树莓派, 大模型, 本地AI, 推理, 边缘计算, 国产大模型, 统一接口
```

## 仓库设置建议

| 设置项 | 推荐值 |
|--------|--------|
| **Visibility** | Public |
| **Default branch** | `main` |
| **License** | MIT |
| **Website** | （可选，可以放文档链接） |
| **Features** | ✅ Issues, ✅ Discussions, ✅ Wiki |
| **Merge strategy** | Squash merge |

## 发布版本建议

首次发布建议：`v1.0.0`

版本命名规范：
- `v1.0.0` — 首个稳定版
- `v1.1.0` — 添加新功能
- `v1.0.1` — Bug 修复

## 创建 Release 时的说明模板

```markdown
## 🦞 PicoClaw API v1.0.0

### ✨ 新特性
- 本地 GGUF 模型推理（基于 llama.cpp）
- 7 家国产云端 API 支持
- Ctrl+K 一键切换提供商
- Web 管理面板
- 流式输出（SSE）
- 2GB 内存优化
- 国内镜像自动回退

### 📦 安装
```bash
git clone https://github.com/YOUR_USERNAME/picoclaw-api.git
cd picoclaw-api
sudo bash install.sh
```

### 📝 系统要求
- 树莓派 4B（2GB+）
- Raspberry Pi OS 64-bit
- Python 3.10+

### 📄 许可证
MIT License
```

---

## 上传步骤

1. 在 GitHub 创建新仓库：https://github.com/new
2. 填写仓库信息（使用上面的描述）
3. 不要勾选 Add a README（因为你本地已有）
4. 在本地执行：

```bash
cd raspberry-pi-lobster
git init
git add .
git commit -m "🦞 Initial release: PicoClaw API v1.0.0"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/picoclaw-api.git
git push -u origin main
```

5. 创建 Release：
   - 在 GitHub 仓库页面点击 "Create a new release"
   - Tag: `v1.0.0`
   - Title: `🦞 PicoClaw API v1.0.0`
   - 填写发布说明
