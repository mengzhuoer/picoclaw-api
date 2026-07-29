# 🦞 Windows 辅助下载脚本
# 当树莓派无法访问 GitHub/HuggingFace 时，在 Windows 下载后传输到 Pi
#
# 使用方法:
#   1. 修改下面的 $PiIP 为你的树莓派 IP
#   2. 运行: .\download-for-pi.ps1

param(
    [string]$PiIP = "192.168.5.33",
    [string]$PiUser = "zhuoer",
    [string]$SSHKey = "$env:USERPROFILE\.ssh\id_ed25519"
)

$ErrorActionPreference = "Stop"

Write-Host "🦞 PicoClaw Pi 辅助下载工具" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 检查 SSH 密钥
if (-not (Test-Path $SSHKey)) {
    Write-Host "SSH 密钥不存在: $SSHKey" -ForegroundColor Red
    Write-Host "请先运行: ssh-keygen -t ed25519 -f $SSHKey -N ''" -ForegroundColor Yellow
    exit 1
}

# 测试 SSH 连接
Write-Host "测试 SSH 连接..." -ForegroundColor Yellow
ssh -i $SSHKey -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${PiUser}@${PiIP} "echo 'SSH OK'" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "SSH 连接失败！请检查 IP 和密钥" -ForegroundColor Red
    exit 1
}
Write-Host "SSH 连接成功 ✓" -ForegroundColor Green
Write-Host ""

# ============================================================
# 1. 下载 llama.cpp
# ============================================================
$llamaZip = "$env:TEMP\llama.cpp-master.zip"
if (-not (Test-Path $llamaZip) -or (Get-Item $llamaZip).Length -lt 10MB) {
    Write-Host "下载 llama.cpp..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "https://github.com/ggerganov/llama.cpp/archive/refs/heads/master.zip" `
            -OutFile $llamaZip -UseBasicParsing
        Write-Host "  下载完成: $([math]::Round((Get-Item $llamaZip).Length/1MB, 2)) MB" -ForegroundColor Green
    } catch {
        Write-Host "  下载失败: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "llama.cpp 已存在: $([math]::Round((Get-Item $llamaZip).Length/1MB, 2)) MB" -ForegroundColor Green
}

# ============================================================
# 2. 下载模型
# ============================================================
$modelFile = "$env:TEMP\qwen2.5-1.5b-instruct-q4_k_m.gguf"
if (-not (Test-Path $modelFile) -or (Get-Item $modelFile).Length -lt 100MB) {
    Write-Host "下载 Qwen2.5-1.5B 模型（约 1GB）..." -ForegroundColor Yellow
    Write-Host "  从 ModelScope（魔搭）下载..." -ForegroundColor Gray

    # 尝试 ModelScope
    try {
        curl.exe -L -o $modelFile "https://modelscope.cn/models/qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/master/qwen2.5-1.5b-instruct-q4_k_m.gguf" --progress-bar
    } catch {
        Write-Host "  ModelScope 失败，尝试 HuggingFace..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf" `
                -OutFile $modelFile -UseBasicParsing
        } catch {
            Write-Host "  下载失败！请手动下载模型" -ForegroundColor Red
            exit 1
        }
    }

    if ((Get-Item $modelFile).Length -gt 100MB) {
        Write-Host "  下载完成: $([math]::Round((Get-Item $modelFile).Length/1MB, 2)) MB" -ForegroundColor Green
    } else {
        Write-Host "  文件太小，可能下载失败" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "模型已存在: $([math]::Round((Get-Item $modelFile).Length/1MB, 2)) MB" -ForegroundColor Green
}

# ============================================================
# 3. 传输到 Pi
# ============================================================
Write-Host ""
Write-Host "传输文件到树莓派..." -ForegroundColor Yellow

# 传输 llama.cpp
Write-Host "  传输 llama.cpp..." -ForegroundColor Gray
scp -i $SSHKey -o StrictHostKeyChecking=no $llamaZip "${PiUser}@${PiIP}:~/llama.cpp-master.zip"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ llama.cpp 传输完成" -ForegroundColor Green
} else {
    Write-Host "  ✗ llama.cpp 传输失败" -ForegroundColor Red
}

# 传输模型
Write-Host "  传输模型（可能需要几分钟）..." -ForegroundColor Gray
scp -i $SSHKey -o StrictHostKeyChecking=no $modelFile "${PiUser}@${PiIP}:~/qwen2.5-1.5b-instruct-q4_k_m.gguf"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ 模型传输完成" -ForegroundColor Green
} else {
    Write-Host "  ✗ 模型传输失败" -ForegroundColor Red
}

# ============================================================
# 4. 在 Pi 上解压和移动文件
# ============================================================
Write-Host ""
Write-Host "在 Pi 上设置文件..." -ForegroundColor Yellow
ssh -i $SSHKey -o StrictHostKeyChecking=no ${PiUser}@${PiIP} @'
cd ~
# 解压 llama.cpp
if [ ! -d "/opt/llama.cpp/CMakeLists.txt" ]; then
    unzip -q ~/llama.cpp-master.zip
    sudo rm -rf /opt/llama.cpp
    sudo mv ~/llama.cpp-master /opt/llama.cpp
    echo "llama.cpp 已解压到 /opt"
fi

# 移动模型
mkdir -p /var/lib/picoclaw/models
if [ -f ~/qwen2.5-1.5b-instruct-q4_k_m.gguf ]; then
    sudo mv ~/qwen2.5-1.5b-instruct-q4_k_m.gguf /var/lib/picoclaw/models/
    sudo chown -R picoclaw:picoclaw /var/lib/picoclaw/models
    echo "模型已移动"
fi

# 清理
rm -f ~/llama.cpp-master.zip
echo "清理完成"
'@

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "🦞 文件准备完成！" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：在 Pi 上运行安装脚本" -ForegroundColor Yellow
Write-Host "  ssh -i $SSHKey ${PiUser}@${PiIP}" -ForegroundColor White
Write-Host "  cd ~/raspberry-pi-lobster" -ForegroundColor White
Write-Host "  sudo bash install.sh" -ForegroundColor White
Write-Host ""
