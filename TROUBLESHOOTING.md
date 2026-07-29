# 🔧 安装问题排查指南

本文档总结了安装过程中遇到的所有问题、原因分析和解决方案。

---

## 📋 问题总结表

| # | 问题 | 原因 | 解决方案 |
|---|------|------|----------|
| 1 | SSH 密码认证失败 | Windows OpenSSH 无法交互式输入密码 | 使用 SSH 密钥认证 |
| 2 | 系统更新太慢 | `apt-get upgrade` 耗时过长 | 跳过更新，只 `apt-get update` |
| 3 | GitHub 无法访问 | GFW 屏蔽 | 在 Windows 下载后 SCP 传输 |
| 4 | HuggingFace 无法访问 | GFW 屏蔽 | 使用 ModelScope（魔搭）镜像 |
| 5 | dpkg 锁文件冲突 | 之前 apt 进程被终止 | 删除锁文件，`dpkg --configure -a` |
| 6 | 后台进程被杀死 | SSH 会话结束时 SIGHUP 信号 | 使用 `setsid` 完全脱离终端 |
| 7 | 缺少 requests 模块 | pip 安装不完整 | 手动 `pip install requests` |
| 8 | venv 权限问题 | venv 用 sudo 创建 | 用 `sudo -u` 运行 pip |
| 9 | 500 Internal Server Error | Starlette TemplateResponse API 变化 | 兼容新旧版本的写法 |
| 10 | sudo 下 `~` 路径错误 | sudo 后 `~` 变成 `/root/` | 使用绝对路径 |
| 11 | sed 命令不生效 | 转义字符问题 | 使用 Python 脚本修改文件 |
| 12 | PowerShell 引号嵌套 | 多层引号转义失败 | 使用脚本文件代替内联命令 |

---

## 🔍 详细问题分析

### 1. SSH 密码认证失败

**现象**：
```
ssh zhuoer@192.168.5.33
# 挂起，等待密码输入
```

**原因**：Windows OpenSSH 客户端在自动化环境中无法弹出密码输入框。

**解决方案**：
```bash
# 生成密钥对
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# 复制公钥到树莓派
ssh-copy-id -i ~/.ssh/id_ed25519.pub zhuoer@192.168.5.33

# 之后可以无密码登录
ssh -i ~/.ssh/id_ed25519 zhuoer@192.168.5.33
```

**备用方案**：使用 PuTTY（支持密码认证）

---

### 2. 系统更新太慢

**现象**：
```
[STEP] 更新系统软件包...
# 卡住 10+ 分钟
```

**原因**：`apt-get upgrade` 需要下载和安装大量更新包。

**解决方案**：
```bash
# 只更新包列表，不升级
apt-get update -qq

# 跳过更新直接安装依赖
```

**优化后的 install.sh 已内置此逻辑**。

---

### 3. GitHub 无法访问

**现象**：
```
fatal: unable to access 'https://github.com/...': Failed to connect to github.com port 443
```

**原因**：GFW 屏蔽了 GitHub。

**解决方案**：

**方案 A**（推荐）：在 Windows 下载后传输
```powershell
# 在 Windows 上下载
Invoke-WebRequest -Uri "https://github.com/ggerganov/llama.cpp/archive/refs/heads/master.zip" `
    -OutFile "$env:TEMP\llama.cpp-master.zip"

# 传输到 Pi
scp "$env:TEMP\llama.cpp-master.zip" zhuoer@192.168.5.33:~/
```

**方案 B**：使用 GitHub 代理
```bash
git clone https://ghproxy.com/https://github.com/ggerganov/llama.cpp.git
```

**方案 C**：配置代理
```bash
export https_proxy=http://your-proxy:port
```

---

### 4. HuggingFace 无法访问

**现象**：
```
Connection to huggingface.co timed out
```

**原因**：GFW 屏蔽了 HuggingFace。

**解决方案**：使用 **ModelScope（魔搭）** 镜像
```bash
# ModelScope 是 HuggingFace 的中国镜像
wget https://modelscope.cn/models/qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/master/qwen2.5-1.5b-instruct-q4_k_m.gguf
```

**已内置到 install.sh 的网络检测逻辑中**。

---

### 5. dpkg 锁文件冲突

**现象**：
```
E: Could not get lock /var/lib/dpkg/lock-frontend
```

**原因**：之前的 apt 进程被强制终止，留下锁文件。

**解决方案**：
```bash
# 终止残留进程
sudo killall apt apt-get dpkg

# 删除锁文件
sudo rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock

# 修复 dpkg 状态
sudo dpkg --configure -a
```

**install.sh 已自动处理**。

---

### 6. 后台进程被杀死

**现象**：
```
nohup bash script.sh > log 2>&1 &
# SSH 断开后被杀死
```

**原因**：SSH 会话结束时发送 SIGHUP 信号，nohup 有时不够。

**解决方案**：使用 `setsid` 完全脱离终端
```bash
# setsid 创建新会话，完全脱离控制终端
sudo setsid bash script.sh > log 2>&1 < /dev/null &
```

**install.sh 的编译步骤已使用此方法**。

---

### 7. 缺少 requests 模块

**现象**：
```
ModuleNotFoundError: No module named 'requests'
```

**原因**：pip 安装不完整或网络中断。

**解决方案**：
```bash
# 激活虚拟环境后安装
/opt/picoclaw-api/venv/bin/pip install requests

# 或者安装所有依赖
/opt/picoclaw-api/venv/bin/pip install fastapi "uvicorn[standard]" httpx jinja2 python-multipart requests
```

**install.sh 已包含 requests 在依赖列表中**。

---

### 8. 500 Internal Server Error

**现象**：
```
访问 http://192.168.5.33:9000 返回 500 错误
日志: TypeError: unhashable type: 'dict'
```

**原因**：新版 Starlette 的 `TemplateResponse` API 格式变化。

**修复前**：
```python
return templates.TemplateResponse("index.html", {"request": request})
```

**修复后**（兼容新旧版本）：
```python
try:
    return templates.TemplateResponse(request, "index.html")
except TypeError:
    return templates.TemplateResponse("index.html", {"request": request})
```

**install.sh 已修复此问题**。

---

## 🚀 优化后的安装流程

### 方式一：树莓派直接安装（推荐，网络通畅时）

```bash
# 1. 克隆或复制项目到树莓派
cd ~/raspberry-pi-lobster

# 2. 一键安装
chmod +x install.sh
sudo bash install.sh
```

### 方式二：Windows 辅助安装（网络受限时）

```powershell
# 在 Windows PowerShell 中运行
.\download-for-pi.ps1 -PiIP 192.168.5.33
```

然后 SSH 到 Pi 运行 install.sh。

### 方式三：手动分步安装

```bash
# 1. 下载 llama.cpp（在 Windows 下载后 SCP 传输）
scp llama.cpp-master.zip pi@192.168.5.33:~/

# 2. 下载模型（使用 ModelScope）
wget https://modelscope.cn/models/qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/master/qwen2.5-1.5b-instruct-q4_k_m.gguf

# 3. 运行安装脚本
sudo bash install.sh
```

---

## 🛡️ 预防措施

### 安装前检查清单

- [ ] 树莓派已开启 SSH
- [ ] 树莓派与电脑在同一网络
- [ ] SD 卡至少有 5GB 可用空间
- [ ] 内存至少 2GB
- [ ] 网络能访问 GitHub 或 ModelScope

### 推荐配置

| 配置项 | 推荐值 | 说明 |
|--------|--------|------|
| 系统 | Raspberry Pi OS 64-bit | 必须 64 位 |
| 内存 | ≥ 2GB | 4GB 更佳 |
| 存储 | ≥ 16GB | 32GB+ 推荐 |
| 散热 | 风扇必须的 | 推理时 CPU 满载 |
| 网络 | 有线以太网 | 比 WiFi 稳定 |

---

## 📞 获取帮助

如果遇到其他问题：

1. 查看安装日志：`cat /tmp/picoclaw-install-*.log`
2. 查看服务日志：`journalctl -u picoclaw-api -f`
3. 检查端口占用：`sudo lsof -i :9000`
4. 重启服务：`sudo systemctl restart picoclaw-api`
