#!/usr/bin/env bash
#
# 🦞 PicoClaw API — 一键安装脚本（优化版 v2）
# 在树莓派4上安装统一 AI 网关（本地推理 + 云端 API）
#
# 使用方法:
#   chmod +x install.sh
#   sudo ./install.sh
#
# 特性:
#   - 自动检测网络（GitHub/HuggingFace 是否可达）
#   - 自动使用镜像源（当主站不可达时）
#   - 自动跳过系统更新（加速安装）
#   - 自动处理权限和锁文件
#   - 后台编译不阻塞 SSH
#   - 详细的错误处理和日志
#

set -uo pipefail

# ============================================================
# 颜色定义
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

log_info()    { echo -e "${GREEN}[INFO]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }
log_step()    { echo -e "${CYAN}[STEP]${NC}    $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*"; }
log_debug()   { echo -e "${BLUE}[DEBUG]${NC}  $*"; }

# ============================================================
# 配置
# ============================================================
INSTALL_DIR="/opt/picoclaw-api"
DATA_DIR="/var/lib/picoclaw"
MODEL_DIR="${DATA_DIR}/models"
LOG_DIR="/var/log/picoclaw-api"
CONFIG_DIR="/etc/picoclaw-api"
SERVICE_USER="picoclaw"
API_PORT="${API_PORT:-9000}"
LLAMA_PORT="${LLAMA_PORT:-8081}"
CTX_SIZE="${CTX_SIZE:-2048}"
THREADS="${THREADS:-4}"

# 模型配置
MODEL_NAME="qwen2.5-1.5b-instruct-q4_k_m.gguf"
MODEL_URL_HF="https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
MODEL_URL_MODELSCOPE="https://modelscope.cn/models/qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/master/qwen2.5-1.5b-instruct-q4_k_m.gguf"

# llama.cpp 源
LLAMA_GIT_URL="https://github.com/ggerganov/llama.cpp.git"
LLAMA_ZIP_URL="https://github.com/ggerganov/llama.cpp/archive/refs/heads/master.zip"

# 日志文件
INSTALL_LOG="/tmp/picoclaw-install-$(date +%Y%m%d-%H%M%S).log"

# ============================================================
# 检查函数
# ============================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 权限运行: sudo $0"
        exit 1
    fi
}

check_architecture() {
    log_step "检查系统架构..."
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64)
            log_success "ARM64 架构 ✓"
            ;;
        armv7l)
            log_warn "ARM32 架构，部分功能可能受限"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
}

check_memory() {
    log_step "检查内存..."
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    log_info "总内存: ${TOTAL_MEM}MB"
    if [[ "$TOTAL_MEM" -lt 2000 ]]; then
        log_warn "内存不足 2GB，将使用最小模型和上下文"
        MODEL_NAME="qwen2.5-0.5b-instruct-q4_k_m.gguf"
        CTX_SIZE=1024
    fi
}

check_disk() {
    log_step "检查磁盘空间..."
    AVAIL_DISK=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
    log_info "可用磁盘: ${AVAIL_DISK}GB"
    if [[ "$AVAIL_DISK" -lt 3 ]]; then
        log_error "磁盘空间不足（需要至少 3GB）"
        exit 1
    fi
}

# ============================================================
# 网络检测
# ============================================================
detect_network() {
    log_step "检测网络连接..."

    # 检测 GitHub
    GITHUB_OK=false
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://github.com 2>/dev/null | grep -q "200\|301\|302"; then
        GITHUB_OK=true
        log_info "GitHub: ✅ 可达"
    else
        log_warn "GitHub: ❌ 不可达（将使用镜像）"
    fi

    # 检测 HuggingFace
    HF_OK=false
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://huggingface.co 2>/dev/null | grep -q "200\|301\|302"; then
        HF_OK=true
        log_info "HuggingFace: ✅ 可达"
    else
        log_warn "HuggingFace: ❌ 不可达（将使用镜像）"
    fi

    # 检测 ModelScope
    MODELSCOPE_OK=false
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://modelscope.cn 2>/dev/null | grep -q "200\|301\|302"; then
        MODELSCOPE_OK=true
        log_info "ModelScope: ✅ 可达"
    else
        log_warn "ModelScope: ❌ 不可达"
    fi

    # 决定下载源
    if [[ "$HF_OK" == true ]]; then
        MODEL_URL="$MODEL_URL_HF"
        MODEL_SOURCE="HuggingFace"
    elif [[ "$MODELSCOPE_OK" == true ]]; then
        MODEL_URL="$MODEL_URL_MODELSCOPE"
        MODEL_SOURCE="ModelScope（魔搭）"
    else
        log_error "无法访问任何模型下载源！"
        log_error "请手动下载模型并放置到: ${MODEL_DIR}/${MODEL_NAME}"
        log_error "下载地址: ${MODEL_URL_MODELSCOPE}"
        read -p "下载完成后按 Enter 继续..."
        if [[ ! -f "${MODEL_DIR}/${MODEL_NAME}" ]]; then
            log_error "模型文件不存在，退出"
            exit 1
        fi
        MODEL_SOURCE="手动"
    fi
    log_info "模型下载源: $MODEL_SOURCE"

    # 决定 llama.cpp 下载方式
    if [[ "$GITHUB_OK" == true ]]; then
        LLAMA_SOURCE="git"
        log_info "llama.cpp 源: GitHub (git clone)"
    else
        LLAMA_SOURCE="zip"
        log_warn "llama.cpp 源: 需要手动提供（GitHub 不可达）"
    fi
}

# ============================================================
# 清理锁文件
# ============================================================
cleanup_locks() {
    log_step "清理 apt 锁文件..."
    killall apt apt-get dpkg 2>/dev/null || true
    sleep 1
    rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock
    dpkg --configure -a 2>/dev/null || true
    log_success "锁文件已清理"
}

# ============================================================
# 安装依赖
# ============================================================
install_dependencies() {
    log_step "安装系统依赖（跳过更新）..."

    # 只更新包列表，不升级（加速）
    apt-get update -qq 2>&1 | tail -3

    # 安装必要依赖
    apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        curl \
        wget \
        unzip \
        build-essential \
        cmake \
        pkg-config \
        jq \
        htop \
        nginx \
        2>&1 | tail -5

    log_success "系统依赖安装完成"
}

# ============================================================
# 创建用户和目录
# ============================================================
setup_user() {
    log_step "创建用户和目录..."

    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$DATA_DIR" -m "$SERVICE_USER"
        log_success "创建用户: $SERVICE_USER"
    else
        log_info "用户已存在"
    fi

    mkdir -p "$INSTALL_DIR" "$MODEL_DIR" "$LOG_DIR" "$CONFIG_DIR"
    mkdir -p "$DATA_DIR/data" "$DATA_DIR/cache"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR" "$LOG_DIR"

    log_success "目录就绪"
}

# ============================================================
# 下载 llama.cpp
# ============================================================
download_llama() {
    log_step "下载 llama.cpp..."

    LLAMA_DIR="/opt/llama.cpp"

    # 检查是否已编译
    if [[ -f "$LLAMA_DIR/build/bin/llama-server" ]]; then
        log_info "llama-server 已存在，跳过下载"
        return
    fi

    # 清理旧目录
    rm -rf "$LLAMA_DIR"

    case "$LLAMA_SOURCE" in
        git)
            log_info "从 GitHub 克隆..."
            git clone --depth 1 "$LLAMA_GIT_URL" "$LLAMA_DIR" 2>&1 | tail -3
            ;;
        zip)
            log_info "需要手动提供 llama.cpp 源码"
            log_info "请下载: $LLAMA_ZIP_URL"
            log_info "解压到: $LLAMA_DIR"
            read -p "完成后按 Enter 继续..."
            if [[ ! -f "$LLAMA_DIR/CMakeLists.txt" ]]; then
                log_error "llama.cpp 源码不存在"
                exit 1
            fi
            ;;
    esac

    log_success "llama.cpp 源码就绪"
}

# ============================================================
# 编译 llama.cpp
# ============================================================
compile_llama() {
    log_step "编译 llama.cpp..."

    LLAMA_DIR="/opt/llama.cpp"

    # 检查是否已编译
    if [[ -f "$LLAMA_DIR/build/bin/llama-server" ]]; then
        log_info "llama-server 已存在，跳过编译"
        return
    fi

    cd "$LLAMA_DIR"
    mkdir -p build && cd build

    log_info "cmake 配置中..."
    cmake .. -DCMAKE_BUILD_TYPE=Release -DGGML_CPU_ARM_ARCH=armv8-a 2>&1 | tail -5

    log_info "开始编译（需要 10-20 分钟）..."
    # 使用 nohup 在后台编译
    nohup cmake --build . --config Release -j$(nproc) > /tmp/llama-compile.log 2>&1 &
    COMPILE_PID=$!
    log_info "编译进程 PID: $COMPILE_PID"

    # 等待编译完成，带进度显示
    local counter=0
    while kill -0 $COMPILE_PID 2>/dev/null; do
        sleep 30
        counter=$((counter + 1))
        local pct=$(grep -o '\[ *[0-9]*%\]' /tmp/llama-compile.log 2>/dev/null | tail -1)
        log_info "编译中... ${counter}x30秒 ${pct:-}"
    done

    # 检查编译结果
    wait $COMPILE_PID
    if [[ -f bin/llama-server ]]; then
        log_success "llama.cpp 编译成功!"
        ls -lh bin/llama-server
    else
        log_error "编译失败，查看日志: /tmp/llama-compile.log"
        tail -30 /tmp/llama-compile.log
        exit 1
    fi
}

# ============================================================
# 下载模型
# ============================================================
download_model() {
    log_step "下载 LLM 模型..."

    MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

    if [[ -f "$MODEL_PATH" ]]; then
        local size_mb=$(du -m "$MODEL_PATH" | cut -f1)
        log_info "模型已存在 (${size_mb}MB)，跳过下载"
        return
    fi

    log_info "从 $MODEL_SOURCE 下载..."
    log_info "URL: $MODEL_URL"
    log_info "目标: $MODEL_PATH"

    # 使用 wget 下载，带进度显示
    wget --progress=dot:mega -O "$MODEL_PATH" "$MODEL_URL" 2>&1 | tail -5

    if [[ -f "$MODEL_PATH" ]]; then
        chown "$SERVICE_USER:$SERVICE_USER" "$MODEL_PATH"
        log_success "模型下载完成: $(du -h "$MODEL_PATH" | cut -f1)"
    else
        log_error "模型下载失败"
        log_error "请手动下载: $MODEL_URL"
        log_error "放置到: $MODEL_PATH"
        exit 1
    fi
}

# ============================================================
# 安装 PicoClaw API
# ============================================================
install_api() {
    log_step "安装 PicoClaw API..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 复制文件
    mkdir -p "$INSTALL_DIR"
    cp -r "$SCRIPT_DIR/picoclaw-api/app" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/picoclaw-api/static" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/picoclaw-api/templates" "$INSTALL_DIR/"

    # Python 虚拟环境（使用用户权限，不用 sudo）
    cd "$INSTALL_DIR"
    sudo -u "$SERVICE_USER" python3 -m venv venv
    sudo -u "$SERVICE_USER" venv/bin/pip install --quiet --upgrade pip
    sudo -u "$SERVICE_USER" venv/bin/pip install --quiet \
        fastapi "uvicorn[standard]" httpx jinja2 python-multipart requests

    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    log_success "API 安装完成"
}

# ============================================================
# 创建 systemd 服务
# ============================================================
create_services() {
    log_step "创建 systemd 服务..."

    MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

    # llama-server 服务
    cat > /etc/systemd/system/llama-server.service << EOF
[Unit]
Description=llama.cpp Server (Local LLM Inference)
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=/opt/llama.cpp/build/bin/llama-server -m $MODEL_PATH --port $LLAMA_PORT --host 127.0.0.1 --ctx-size $CTX_SIZE --threads $threads --n-gpu-layers 0
WorkingDirectory=$DATA_DIR
Restart=always
RestartSec=5
StandardOutput=append:$LOG_DIR/llama-server.log
StandardError=append:$LOG_DIR/llama-server.log

[Install]
WantedBy=multi-user.target
EOF

    # PicoClaw API 服务
    cat > /etc/systemd/system/picoclaw-api.service << EOF
[Unit]
Description=PicoClaw API - Unified AI Gateway
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
Environment=PATH=$INSTALL_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=LLAMA_BIN=/opt/llama.cpp/build/bin/llama-server
Environment=MODEL_DIR=$MODEL_DIR
Environment=LLAMA_PORT=$LLAMA_PORT
Environment=API_PORT=$API_PORT
Environment=CONFIG_PATH=$CONFIG_DIR/providers.json
Environment=CTX_SIZE=$CTX_SIZE
Environment=THREADS=$THREADS
WorkingDirectory=$INSTALL_DIR/app
ExecStart=$INSTALL_DIR/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port $API_PORT
Restart=always
RestartSec=5
StandardOutput=append:$LOG_DIR/picoclaw-api.log
StandardError=append:$LOG_DIR/picoclaw-api.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable llama-server.service
    systemctl enable picoclaw-api.service

    log_success "服务创建完成"
}

# ============================================================
# 启动服务
# ============================================================
start_services() {
    log_step "启动服务..."

    systemctl start llama-server
    sleep 5

    if systemctl is-active --quiet llama-server; then
        log_success "llama-server 启动成功"
    else
        log_error "llama-server 启动失败"
        journalctl -u llama-server --no-pager -n 10
    fi

    systemctl start picoclaw-api
    sleep 3

    if systemctl is-active --quiet picoclaw-api; then
        log_success "picoclaw-api 启动成功"
    else
        log_warn "picoclaw-api 启动中，等待模型加载..."
        sleep 10
        if systemctl is-active --quiet picoclaw-api; then
            log_success "picoclaw-api 启动成功"
        else
            log_error "picoclaw-api 启动失败"
            journalctl -u picoclaw-api --no-pager -n 10
        fi
    fi
}

# ============================================================
# 验证安装
# ============================================================
verify_installation() {
    log_step "验证安装..."

    local success=true

    # 检查服务
    if systemctl is-active --quiet llama-server; then
        log_success "llama-server 运行中"
    else
        log_error "llama-server 未运行"
        success=false
    fi

    if systemctl is-active --quiet picoclaw-api; then
        log_success "picoclaw-api 运行中"
    else
        log_error "picoclaw-api 未运行"
        success=false
    fi

    # 检查 API 端口
    if curl -s --connect-timeout 5 http://localhost:$API_PORT/api/health > /dev/null 2>&1; then
        log_success "API 健康检查通过"
    else
        log_warn "API 健康检查失败（可能还在启动中）"
    fi

    if $success; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# 显示完成信息
# ============================================================
show_completion() {
    local IP_ADDR
    IP_ADDR=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║          🦞 PicoClaw API 安装完成！                          ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Web 管理面板:${NC}     http://${IP_ADDR}:${API_PORT}"
    echo -e "  ${CYAN}API 对话接口:${NC}     http://${IP_ADDR}:${API_PORT}/api/chat"
    echo -e "  ${CYAN}API 健康检查:${NC}     http://${IP_ADDR}:${API_PORT}/api/health"
    echo -e "  ${CYAN}API 状态查询:${NC}     http://${IP_ADDR}:${API_PORT}/api/status"
    echo ""
    echo -e "  ${YELLOW}常用命令:${NC}"
    echo -e "    查看状态:   systemctl status picoclaw-api"
    echo -e "    查看日志:   journalctl -u picoclaw-api -f"
    echo -e "    重启服务:   systemctl restart picoclaw-api"
    echo ""
    echo -e "  ${YELLOW}支持的云端 API:${NC}"
    echo -e "    🟠 通义千问  🔵 DeepSeek  🟢 智谱 GLM  🌙 Kimi"
    echo -e "    🟣 MiniMax   🔷 百度文心  ⭐ 讯飞星火"
    echo ""
    echo -e "${GREEN}${BOLD}🦞 在浏览器中打开 http://${IP_ADDR}:${API_PORT} 开始使用！${NC}"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo -e "${BOLD}🦞 PicoClaw API 一键安装（优化版 v2）${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""

    # 记录开始时间
    local START_TIME=$(date +%s)

    # 检查
    check_root
    check_architecture
    check_memory
    check_disk

    echo ""

    # 网络检测
    detect_network

    echo ""

    # 清理锁文件
    cleanup_locks

    # 安装步骤
    install_dependencies
    setup_user
    download_llama
    compile_llama
    download_model
    install_api
    create_services
    start_services

    echo ""

    # 验证
    verify_installation

    # 显示完成信息
    show_completion

    # 计算耗时
    local END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))
    local MINUTES=$((ELAPSED / 60))
    local SECONDS=$((ELAPSED % 60))
    log_info "总耗时: ${MINUTES}分${SECONDS}秒"
}

# 执行主流程
main "$@" 2>&1 | tee "$INSTALL_LOG"

log_info "安装日志已保存到: $INSTALL_LOG"
