#!/usr/bin/env bash
#
# 🦞 PicoClaw 树莓派4 一键安装脚本
# 在 Debian (Raspberry Pi OS) 上自动部署个人 AI 助手
#
# 使用方法:
#   chmod +x picoclaw-setup.sh
#   ./picoclaw-setup.sh
#
# 或者一键执行:
#   curl -sSL https://raw.githubusercontent.com/your-repo/picoclaw-setup/main/setup.sh | bash
#

set -euo pipefail

# ============================================================
# 颜色定义
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================
# 日志函数
# ============================================================
log_info()    { echo -e "${GREEN}[INFO]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }
log_step()    { echo -e "${CYAN}[STEP]${NC}    $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*"; }

# ============================================================
# 配置变量
# ============================================================
PICOCLAW_VERSION="latest"
INSTALL_DIR="/opt/picoclaw"
DATA_DIR="/var/lib/picoclaw"
LOG_DIR="/var/log/picoclaw"
CONFIG_DIR="/etc/picoclaw"
SERVICE_USER="picoclaw"
LLM_MODEL="${LLM_MODEL:-phi-3-mini-4k-instruct.Q4_K_M.gguf}"
LLM_MODEL_URL="${LLM_MODEL_URL:-https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/phi-3-mini-4k-instruct.Q4_K_M.gguf}"
WEB_PORT="${WEB_PORT:-8080}"
LLAMA_CPP_PORT="${LLAMA_CPP_PORT:-8081}"

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
            log_success "检测到 ARM64 架构 (树莓派4 64位系统 ✓)"
            ;;
        armv7l)
            log_warn "检测到 ARM32 架构，部分功能可能受限"
            log_warn "建议安装 Raspberry Pi OS (64-bit) 以获得最佳体验"
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
        log_warn "内存不足 2GB，建议使用更小的模型 (如 TinyLlama 1.1B)"
        LLM_MODEL="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
        LLM_MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    elif [[ "$TOTAL_MEM" -lt 4000 ]]; then
        log_warn "内存 2-4GB，使用 Phi-3-Mini 3.8B 模型"
        LLM_MODEL="phi-3-mini-4k-instruct.Q4_K_M.gguf"
        LLM_MODEL_URL="https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/phi-3-mini-4k-instruct.Q4_K_M.gguf"
    else
        log_success "内存充足 (4GB+)，可使用 Llama 3.2 3B 模型"
        LLM_MODEL="llama-3.2-3b-instruct.Q4_K_M.gguf"
        LLM_MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct.Q4_K_M.gguf"
    fi
}

check_internet() {
    log_step "检查网络连接..."
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log_success "网络连接正常"
    else
        log_error "无法连接互联网，请检查网络配置"
        exit 1
    fi
}

# ============================================================
# 系统更新与依赖安装
# ============================================================
update_system() {
    log_step "更新系统软件包..."
    apt-get update -qq
    apt-get upgrade -y -qq
    log_success "系统更新完成"
}

install_dependencies() {
    log_step "安装系统依赖..."
    apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        curl \
        wget \
        build-essential \
        cmake \
        pkg-config \
        libasound2-dev \
        portaudio19-dev \
        libportaudio2 \
        libportaudiocpp0 \
        ffmpeg \
        sox \
        libsox-fmt-all \
        jq \
        htop \
        unzip \
        sqlite3 \
        nginx \
        certbot \
        python3-certbot-nginx \
        avahi-daemon \
        &>/dev/null
    log_success "系统依赖安装完成"
}

# ============================================================
# 创建用户和目录
# ============================================================
setup_user() {
    log_step "创建服务用户和目录..."

    # 创建专用用户
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$DATA_DIR" -m "$SERVICE_USER"
        log_success "创建用户: $SERVICE_USER"
    else
        log_info "用户 $SERVICE_USER 已存在"
    fi

    # 创建目录结构
    mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR" "$CONFIG_DIR"
    mkdir -p "$DATA_DIR/models" "$DATA_DIR/data" "$DATA_DIR/cache"

    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR" "$LOG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    log_success "目录结构创建完成"
}

# ============================================================
# 安装 llama.cpp
# ============================================================
install_llama_cpp() {
    log_step "编译安装 llama.cpp (本地 LLM 推理引擎)..."

    local LLAMA_DIR="/opt/llama.cpp"

    if [[ -f "$LLAMA_DIR/build/bin/llama-server" ]]; then
        log_info "llama-server 已存在，跳过编译"
        return
    fi

    # 克隆仓库
    cd /opt
    if [[ -d "llama.cpp" ]]; then
        rm -rf llama.cpp
    fi
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git &>/dev/null

    cd llama.cpp

    # 编译 (ARM64 优化)
    mkdir -p build && cd build

    local CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"

    # 树莓派4 支持 NEON 指令集
    if [[ "$ARCH" == "aarch64" ]]; then
        CMAKE_FLAGS="$CMAKE_FLAGS -DGGML_CPU_ARM_ARCH=armv8-a"
    fi

    cmake .. $CMAKE_FLAGS &>/dev/null
    cmake --build . --config Release -j$(nproc) &>/dev/null

    log_success "llama.cpp 编译完成"
}

# ============================================================
# 下载 LLM 模型
# ============================================================
download_model() {
    log_step "下载 LLM 模型: $LLM_MODEL"

    local MODEL_PATH="$DATA_DIR/models/$LLM_MODEL"

    if [[ -f "$MODEL_PATH" ]]; then
        log_info "模型已存在，跳过下载"
        return
    fi

    log_info "模型大小约 2-4GB，下载可能需要几分钟..."
    wget -q --show-progress -O "$MODEL_PATH" "$LLM_MODEL_URL"

    chown "$SERVICE_USER:$SERVICE_USER" "$MODEL_PATH"
    log_success "模型下载完成: $MODEL_PATH"
}

# ============================================================
# 安装 PicoClaw
# ============================================================
install_picoclaw() {
    log_step "安装 PicoClaw..."

    cd "$INSTALL_DIR"

    # 克隆 PicoClaw
    if [[ -d ".git" ]]; then
        git pull &>/dev/null
    else
        git clone --depth 1 https://github.com/nicholasgasior/picoclaw.git . &>/dev/null
    fi

    # 创建 Python 虚拟环境
    python3 -m venv venv
    source venv/bin/activate

    # 安装依赖
    pip install --quiet --upgrade pip
    pip install --quiet -r requirements.txt
    pip install --quiet -e .

    # 安装额外依赖 (语音、智能家居)
    pip install --quiet \
        SpeechRecognition \
        pyttsx3 \
        pyaudio \
        paho-mqtt \
        homeassistant-api \
        &>/dev/null || log_warn "部分可选依赖安装失败，语音/智能家居功能可能不可用"

    deactivate
    log_success "PicoClaw 安装完成"
}

# ============================================================
# 生成配置文件
# ============================================================
generate_config() {
    log_step "生成配置文件..."

    cat > "$CONFIG_DIR/config.yaml" << EOF
# 🦞 PicoClaw 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 服务配置
server:
  host: 0.0.0.0
  port: ${WEB_PORT}
  debug: false

# 数据存储
data:
  dir: ${DATA_DIR}/data
  database: ${DATA_DIR}/data/picoclaw.db
  cache: ${DATA_DIR}/cache

# LLM 配置
llm:
  backend: llama.cpp
  model: ${DATA_DIR}/models/${LLM_MODEL}
  base_url: http://localhost:${LLAMA_CPP_PORT}
  context_length: 4096
  temperature: 0.7
  max_tokens: 2048
  threads: 4  # 树莓派4 4核

# 语音配置
voice:
  enabled: true
  wake_word: "hey lobster"
  stt_engine: whisper  # whisper / google
  tts_engine: pyttsx3
  microphone_device: default
  speaker_device: default
  language: zh-CN

# 智能家居集成
smart_home:
  enabled: false
  home_assistant:
    url: "http://homeassistant.local:8123"
    token: ""  # 在此填入 HA 长期访问令牌
  mqtt:
    broker: "localhost"
    port: 1883
    username: ""
    password: ""

# 日志配置
logging:
  level: INFO
  file: ${LOG_DIR}/picoclaw.log
  max_size: 10MB
  backup_count: 5

# 安全配置
security:
  api_key: "$(openssl rand -hex 32)"
  allowed_hosts:
    - "localhost"
    - "127.0.0.1"
    - "$(hostname -I | awk '{print $1}')"
EOF

    chown -R "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR"
    chmod 600 "$CONFIG_DIR/config.yaml"

    log_success "配置文件生成完成: $CONFIG_DIR/config.yaml"
}

# ============================================================
# 创建 systemd 服务
# ============================================================
create_services() {
    log_step "创建 systemd 服务..."

    # llama-server 服务
    cat > /etc/systemd/system/llama-server.service << EOF
[Unit]
Description=llama.cpp Server (Local LLM Inference)
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
ExecStart=/opt/llama.cpp/build/bin/llama-server \
    -m ${DATA_DIR}/models/${LLM_MODEL} \
    --port ${LLAMA_CPP_PORT} \
    --host 127.0.0.1 \
    --ctx-size 4096 \
    --threads 4 \
    --n-gpu-layers 0
WorkingDirectory=${DATA_DIR}
Restart=always
RestartSec=5
StandardOutput=append:${LOG_DIR}/llama-server.log
StandardError=append:${LOG_DIR}/llama-server.log

[Install]
WantedBy=multi-user.target
EOF

    # PicoClaw 服务
    cat > /etc/systemd/system/picoclaw.service << EOF
[Unit]
Description=PicoClaw - Self-Hosted AI Assistant
After=network.target llama-server.service
Wants=llama-server.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
Environment=PATH=${INSTALL_DIR}/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${INSTALL_DIR}/venv/bin/picoclaw serve --config ${CONFIG_DIR}/config.yaml
WorkingDirectory=${INSTALL_DIR}
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/picoclaw.log
StandardError=append:${LOG_DIR}/picoclaw.log

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd
    systemctl daemon-reload

    # 启用服务 (开机自启)
    systemctl enable llama-server.service
    systemctl enable picoclaw.service

    log_success "systemd 服务创建完成"
}

# ============================================================
# 配置 Nginx 反向代理 (可选)
# ============================================================
setup_nginx() {
    log_step "配置 Nginx 反向代理..."

    cat > /etc/nginx/sites-available/picoclaw << EOF
server {
    listen 80;
    server_name _;  # 接受所有域名

    # WebSocket 支持
    location /ws {
        proxy_pass http://127.0.0.1:${WEB_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }

    location / {
        proxy_pass http://127.0.0.1:${WEB_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/picoclaw /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # 测试配置
    nginx -t &>/dev/null

    # 重启 Nginx
    systemctl restart nginx
    systemctl enable nginx

    log_success "Nginx 配置完成"
}

# ============================================================
# 启动服务
# ============================================================
start_services() {
    log_step "启动服务..."

    # 启动 llama-server
    systemctl start llama-server
    sleep 3

    # 检查 llama-server 是否启动成功
    if systemctl is-active --quiet llama-server; then
        log_success "llama-server 启动成功"
    else
        log_error "llama-server 启动失败，请检查日志: journalctl -u llama-server"
        return 1
    fi

    # 启动 PicoClaw
    systemctl start picoclaw
    sleep 3

    if systemctl is-active --quiet picoclaw; then
        log_success "PicoClaw 启动成功"
    else
        log_error "PicoClaw 启动失败，请检查日志: journalctl -u picoclaw"
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
    echo -e "${GREEN}${BOLD}║          🦞 PicoClaw 安装完成！                              ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Web 面板:${NC}     http://${IP_ADDR}:${WEB_PORT}"
    echo -e "  ${CYAN}Web 面板:${NC}     http://localhost:${WEB_PORT}"
    echo -e "  ${CYAN}配置文件:${NC}     ${CONFIG_DIR}/config.yaml"
    echo -e "  ${CYAN}模型目录:${NC}     ${DATA_DIR}/models/"
    echo -e "  ${CYAN}日志目录:${NC}     ${LOG_DIR}/"
    echo ""
    echo -e "  ${YELLOW}常用命令:${NC}"
    echo -e "    查看状态:   systemctl status picoclaw"
    echo -e "    查看日志:   journalctl -u picoclaw -f"
    echo -e "    重启服务:   systemctl restart picoclaw"
    echo -e "    停止服务:   systemctl stop picoclaw"
    echo ""
    echo -e "  ${YELLOW}模型切换:${NC}"
    echo -e "    编辑 ${CONFIG_DIR}/config.yaml 中的 llm.model 路径"
    echo -e "    然后执行: systemctl restart llama-server"
    echo ""
    echo -e "  ${YELLOW}推荐模型 (按内存选择):${NC}"
    echo -e "    2GB RAM:  TinyLlama 1.1B  /  Qwen2.5 1.5B"
    echo -e "    4GB RAM:  Phi-3-Mini 3.8B  /  Llama 3.2 3B"
    echo -e "    8GB RAM:  Llama 3.1 8B  /  Qwen2.5 7B"
    echo ""
    echo -e "${GREEN}${BOLD}🦞 你的个人 AI 助手已就绪！${NC}"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo -e "${BOLD}🦞 PicoClaw 树莓派4 一键安装脚本${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""

    check_root
    check_architecture
    check_memory
    check_internet

    echo ""
    log_step "开始安装流程..."
    echo ""

    update_system
    install_dependencies
    setup_user
    install_llama_cpp
    download_model
    install_picoclaw
    generate_config
    create_services
    setup_nginx
    start_services

    show_completion
}

# 执行主流程
main "$@"
