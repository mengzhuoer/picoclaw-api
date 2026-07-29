#!/usr/bin/env bash
#
# 🦞 OpenClaw 树莓派4 一键安装脚本
# 全功能 AI Agent 框架，支持多 Agent 工作流
#
# 使用方法:
#   chmod +x openclaw-setup.sh
#   sudo ./openclaw-setup.sh
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
NC='\033[0m'
BOLD='\033[1m'

log_info()    { echo -e "${GREEN}[INFO]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $*"; }
log_step()    { echo -e "${CYAN}[STEP]${NC}    $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $*"; }

# ============================================================
# 配置变量
# ============================================================
OPENCLAW_VERSION="latest"
INSTALL_DIR="/opt/openclaw"
DATA_DIR="/var/lib/openclaw"
LOG_DIR="/var/log/openclaw"
CONFIG_DIR="/etc/openclaw"
SERVICE_USER="openclaw"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:3b}"
WEB_PORT="${WEB_PORT:-9090}"
OLLAMA_PORT="11434"

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
            log_success "检测到 ARM64 架构 ✓"
            ;;
        armv7l)
            log_warn "检测到 ARM32 架构，建议使用 aarch64 (64位) 系统"
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
    if [[ "$TOTAL_MEM" -lt 4000 ]]; then
        log_warn "内存不足 4GB，建议使用 PicoClaw 替代"
        log_warn "或选择更小的模型: ollama pull llama3.2:1b"
        OLLAMA_MODEL="tinyllama:1.1b"
    fi
}

check_internet() {
    log_step "检查网络连接..."
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log_success "网络连接正常"
    else
        log_error "无法连接互联网"
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
        jq \
        htop \
        nginx \
        sqlite3 \
        &>/dev/null
    log_success "系统依赖安装完成"
}

# ============================================================
# 安装 Ollama
# ============================================================
install_ollama() {
    log_step "安装 Ollama (LLM 运行时)..."

    if command -v ollama &>/dev/null; then
        log_info "Ollama 已安装，跳过"
        return
    fi

    curl -fsSL https://ollama.com/install.sh | sh

    # 启动 Ollama
    systemctl enable ollama
    systemctl start ollama

    # 等待服务就绪
    sleep 5

    log_success "Ollama 安装完成"
}

# ============================================================
# 下载 LLM 模型
# ============================================================
download_model() {
    log_step "下载 LLM 模型: $OLLAMA_MODEL"

    if ollama list 2>/dev/null | grep -q "${OLLAMA_MODEL%%:*}"; then
        log_info "模型已存在，跳过下载"
        return
    fi

    log_info "模型大小约 2-5GB，下载可能需要几分钟..."
    ollama pull "$OLLAMA_MODEL"

    log_success "模型下载完成"
}

# ============================================================
# 创建用户和目录
# ============================================================
setup_user() {
    log_step "创建服务用户和目录..."

    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$DATA_DIR" -m "$SERVICE_USER"
        log_success "创建用户: $SERVICE_USER"
    fi

    mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR" "$CONFIG_DIR"
    mkdir -p "$DATA_DIR/agents" "$DATA_DIR/tools" "$DATA_DIR/data"

    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR" "$LOG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    log_success "目录结构创建完成"
}

# ============================================================
# 安装 OpenClaw
# ============================================================
install_openclaw() {
    log_step "安装 OpenClaw..."

    cd "$INSTALL_DIR"

    # 克隆仓库
    if [[ -d ".git" ]]; then
        git pull &>/dev/null
    else
        git clone --depth 1 https://github.com/openclaw-ai/openclaw.git . &>/dev/null || \
        git clone --depth 1 https://github.com/open-claw/open-claw.git . &>/dev/null
    fi

    # 创建虚拟环境
    python3 -m venv venv
    source venv/bin/activate

    # 安装依赖
    pip install --quiet --upgrade pip
    pip install --quiet -r requirements.txt
    pip install --quiet -e .

    deactivate
    log_success "OpenClaw 安装完成"
}

# ============================================================
# 生成配置文件
# ============================================================
generate_config() {
    log_step "生成配置文件..."

    cat > "$CONFIG_DIR/config.yaml" << EOF
# 🦞 OpenClaw 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 服务配置
server:
  host: 0.0.0.0
  port: ${WEB_PORT}
  debug: false

# 数据存储
data:
  dir: ${DATA_DIR}/data
  database: ${DATA_DIR}/data/openclaw.db

# LLM 配置 (使用 Ollama)
llm:
  backend: ollama
  model: ${OLLAMA_MODEL}
  base_url: http://localhost:${OLLAMA_PORT}
  temperature: 0.7
  max_tokens: 4096

# Agent 配置
agents:
  default_assistant:
    name: "龙虾助手"
    description: "个人 AI 助手"
    system_prompt: |
      你是一个运行在树莓派上的个人 AI 助手，名叫"龙虾"。
      你高效、友好，能够帮助用户完成各种任务。
      请用中文回答，除非用户用其他语言提问。
    tools:
      - web_search
      - file_read
      - file_write
      - shell_execute
      - python_execute

# 工具配置
tools:
  web_search:
    enabled: true
    provider: duckduckgo
  file_read:
    enabled: true
    base_dir: ${DATA_DIR}
  file_write:
    enabled: true
    base_dir: ${DATA_DIR}
  shell_execute:
    enabled: true
    allowed_commands:
      - "ls"
      - "cat"
      - "head"
      - "tail"
      - "grep"
      - "find"
      - "systemctl status"
  python_execute:
    enabled: true
    timeout: 30

# 插件系统
plugins:
  enabled: true
  directory: ${INSTALL_DIR}/plugins
  auto_load: true

# 日志配置
logging:
  level: INFO
  file: ${LOG_DIR}/openclaw.log
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

    log_success "配置文件生成完成"
}

# ============================================================
# 创建 systemd 服务
# ============================================================
create_services() {
    log_step "创建 systemd 服务..."

    cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=OpenClaw - Self-Hosted AI Agent Framework
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
Environment=PATH=${INSTALL_DIR}/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${INSTALL_DIR}/venv/bin/openclaw serve --config ${CONFIG_DIR}/config.yaml
WorkingDirectory=${INSTALL_DIR}
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/openclaw.log
StandardError=append:${LOG_DIR}/openclaw.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable openclaw.service

    log_success "systemd 服务创建完成"
}

# ============================================================
# 配置 Nginx 反向代理
# ============================================================
setup_nginx() {
    log_step "配置 Nginx 反向代理..."

    cat > /etc/nginx/sites-available/openclaw << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${WEB_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /ws {
        proxy_pass http://127.0.0.1:${WEB_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    nginx -t &>/dev/null
    systemctl restart nginx
    systemctl enable nginx

    log_success "Nginx 配置完成"
}

# ============================================================
# 启动服务
# ============================================================
start_services() {
    log_step "启动服务..."

    systemctl start openclaw
    sleep 5

    if systemctl is-active --quiet openclaw; then
        log_success "OpenClaw 启动成功"
    else
        log_error "OpenClaw 启动失败，请检查日志: journalctl -u openclaw"
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
    echo -e "${GREEN}${BOLD}║          🦞 OpenClaw 安装完成！                              ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Web 面板:${NC}     http://${IP_ADDR}:${WEB_PORT}"
    echo -e "  ${CYAN}配置文件:${NC}     ${CONFIG_DIR}/config.yaml"
    echo -e "  ${CYAN}模型管理:${NC}     ollama list / ollama pull <model>"
    echo ""
    echo -e "  ${YELLOW}常用命令:${NC}"
    echo -e "    查看状态:   systemctl status openclaw"
    echo -e "    查看日志:   journalctl -u openclaw -f"
    echo -e "    重启服务:   systemctl restart openclaw"
    echo -e "    Ollama模型: ollama list"
    echo ""
    echo -e "  ${YELLOW}推荐模型:${NC}"
    echo -e "    4GB RAM:  llama3.2:3b  /  phi3:3.8b  /  qwen2.5:3b"
    echo -e "    8GB RAM:  llama3.1:8b  /  qwen2.5:7b  /  mistral:7b"
    echo ""
    echo -e "${GREEN}${BOLD}🦞 OpenClaw AI Agent 已就绪！${NC}"
    echo ""
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo -e "${BOLD}🦞 OpenClaw 树莓派4 一键安装脚本${NC}"
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
    install_ollama
    setup_user
    download_model
    install_openclaw
    generate_config
    create_services
    setup_nginx
    start_services

    show_completion
}

main "$@"
