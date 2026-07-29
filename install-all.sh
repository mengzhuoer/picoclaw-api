#!/usr/bin/env bash
#
# 🦞 PicoClaw API — 一键安装入口（优化版 v2）
# 自动检测环境并选择最佳安装方式
#
# 使用方法:
#   chmod +x install-all.sh
#   sudo ./install-all.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "🦞 PicoClaw AI 助手 — 一键安装"
echo "==============================="
echo ""

# 检查是否在树莓派上运行
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "armv7l" ]]; then
    echo "⚠️  当前不在树莓派上（架构: $ARCH）"
    echo ""
    echo "如果你在 Windows 上，请使用以下方式安装："
    echo ""
    echo "  方式一：SSH 远程安装"
    echo "    1. 确保树莓派已开启 SSH 并在同一网络"
    echo "    2. 在 Windows PowerShell 中运行:"
    echo "       .\\download-for-pi.ps1 -PiIP <树莓派IP>"
    echo ""
    echo "  方式二：手动安装"
    echo "    1. 把项目文件夹复制到树莓派"
    echo "    2. SSH 登录树莓派"
    echo "    3. cd raspberry-pi-lobster"
    echo "    4. sudo bash install.sh"
    echo ""
    read -p "是否在当前位置继续安装？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 运行主安装脚本
exec sudo bash "$SCRIPT_DIR/install.sh" "$@"
