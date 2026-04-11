#!/bin/bash
# ============================================================
# 增强版安装脚本 - CDN网络 + 分布式计算节点
# 作者：shc
# 功能：
#   - 自动检测公网IP和算力
#   - 根据条件安装CDN服务器/计算节点
#   - 支持模型自动下载（多源自动选择）
#   - CDN服务器列表管理
# ============================================================

set -e

# ============================================================
# 配置
# ============================================================
VERSION="2.0.0"
INSTALL_DIR="/opt/cdn-network"
CONFIG_DIR="/etc/cdn-network"
LOG_DIR="/var/log/cdn-network"
MODEL_DIR="/opt/cdn-network/models"
CDN_LIST_URL="https://raw.githubusercontent.com/shenwenAI/Calculate-cdn.sh/main/cdn-list.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认语言
LANGUAGE="en"

# ============================================================
# 多语言文本
# ============================================================
declare -A TEXT_CN
declare -A TEXT_EN

TEXT_CN=(
    [title]="============================================================"
    [welcome]="        欢迎使用 CDN 网络安装程序 v${VERSION}"
    [author]="        作者：shc"
    [select_lang]="请选择语言 / Please select language:"
    [option_cn]="1) 中文 (Chinese)"
    [option_en]="2) English (英文)"
    [input_prompt]="请输入选项 (1-2): "
    [invalid_input]="无效输入，请重新选择"

    # 系统检测
    [detecting_system]="正在检测系统环境..."
    [detecting_ip]="📍 正在检测公网 IP 地址..."
    [detecting_gpu]="🖥️  正在检测 GPU/算力..."
    [checking_model]="📦 正在检查已安装组件..."

    # 检测结果
    [public_ip]="公网 IP"
    [private_ip]="私有 IP (NAT后方)"
    [no_public_ip]="未检测到公网 IP"
    [gpu_detected]="检测到 GPU"
    [no_gpu]="未检测到 GPU"
    [vram]="显存"
    [memory]="内存"

    # 安装选项
    [install_mode]="安装模式选择"
    [mode_cdn_full]="完整 CDN 节点 (公网IP + 算力)"
    [mode_cdn_proxy]="CDN 代理节点 (公网IP，无算力)"
    [mode_compute]="计算节点 (无公网IP，有算力)"
    [mode_light]="轻量节点 (无公网IP，无算力)"
    [auto_detect]="自动检测推荐"

    # 安装过程
    [installing]="正在安装..."
    [installing_cdn]="安装 CDN 服务..."
    [installing_swlm]="安装 swlm.cpp..."
    [installing_model]="下载 AI 模型..."
    [installing_web]="安装管理网页..."
    [configuring]="配置服务..."
    [starting]="启动服务..."

    # 组件
    [component_cdn]="CDN 服务器"
    [component_swlm]="swlm.cpp 推理引擎"
    [component_model]="AI 模型"
    [component_web]="管理网页"
    [component_proxy]="API 代理"

    # 模型下载
    [select_model]="选择模型"
    [model_small]="shenwen-coderV2-Q4_K_M (4GB, 快速)"
    [model_medium]="shenwen-coderV2-Q5_K_M (6GB, 平衡)"
    [model_large]="shenwen-coderV2-Q8_0 (12GB, 高质量)"
    [downloading]="下载中..."
    [download_speed]="下载速度"
    [trying_hf]="尝试 HuggingFace..."
    [trying_mirror]="尝试镜像站..."
    [download_complete]="下载完成"
    [download_failed]="下载失败"

    # CDN管理
    [cdn_servers]="CDN 服务器列表"
    [nearest_cdn]="最近的 CDN 服务器"
    [add_cdn]="添加 CDN 服务器"
    [remove_cdn]="移除 CDN 服务器"
    [test_latency]="测试延迟"

    # 完成
    [install_complete]="安装完成!"
    [install_failed]="安装失败"
    [service_status]="服务状态"
    [api_endpoint]="API 端点"
    [web_panel]="管理面板"
    [admin_token]="管理员令牌"

    # 错误
    [error_curl]="错误：需要安装 curl"
    [error_gpu]="警告：GPU 检测失败"
    [error_network]="网络连接失败"
    [error_disk]="磁盘空间不足"

    # 确认
    [confirm_install]="确认安装?"
    [press_enter]="按回车键继续..."
    [yes]="是 (Y)"
    [no]="否 (N)"
)

TEXT_EN=(
    [title]="============================================================"
    [welcome]="        Welcome to CDN Network Installer v${VERSION}"
    [author]="        Author: shc"
    [select_lang]="Please select language / 请选择语言:"
    [option_cn]="1) 中文 (Chinese)"
    [option_en]="2) English (英文)"
    [input_prompt]="Enter option (1-2): "
    [invalid_input]="Invalid input, please select again"

    # System detection
    [detecting_system]="Detecting system environment..."
    [detecting_ip]="📍 Detecting public IP address..."
    [detecting_gpu]="🖥️  Detecting GPU/Compute..."
    [checking_model]="📦 Checking installed components..."

    # Detection results
    [public_ip]="Public IP"
    [private_ip]="Private IP (Behind NAT)"
    [no_public_ip]="No public IP detected"
    [gpu_detected]="GPU detected"
    [no_gpu]="No GPU detected"
    [vram]="VRAM"
    [memory]="Memory"

    # Install modes
    [install_mode]="Installation Mode"
    [mode_cdn_full]="Full CDN Node (Public IP + Compute)"
    [mode_cdn_proxy]="CDN Proxy Node (Public IP, No Compute)"
    [mode_compute]="Compute Node (No Public IP, Has Compute)"
    [mode_light]="Light Node (No Public IP, No Compute)"
    [auto_detect]="Auto-detect (Recommended)"

    # Installation process
    [installing]="Installing..."
    [installing_cdn]="Installing CDN service..."
    [installing_swlm]="Installing swlm.cpp..."
    [installing_model]="Downloading AI model..."
    [installing_web]="Installing management web..."
    [configuring]="Configuring services..."
    [starting]="Starting services..."

    # Components
    [component_cdn]="CDN Server"
    [component_swlm]="swlm.cpp Engine"
    [component_model]="AI Model"
    [component_web]="Management Web"
    [component_proxy]="API Proxy"

    # Model download
    [select_model]="Select Model"
    [model_small]="shenwen-coderV2-Q4_K_M (4GB, Fast)"
    [model_medium]="shenwen-coderV2-Q5_K_M (6GB, Balanced)"
    [model_large]="shenwen-coderV2-Q8_0 (12GB, High Quality)"
    [downloading]="Downloading..."
    [download_speed]="Download speed"
    [trying_hf]="Trying HuggingFace..."
    [trying_mirror]="Trying mirror..."
    [download_complete]="Download complete"
    [download_failed]="Download failed"

    # CDN management
    [cdn_servers]="CDN Server List"
    [nearest_cdn]="Nearest CDN Server"
    [add_cdn]="Add CDN Server"
    [remove_cdn]="Remove CDN Server"
    [test_latency]="Test Latency"

    # Completion
    [install_complete]="Installation Complete!"
    [install_failed]="Installation Failed"
    [service_status]="Service Status"
    [api_endpoint]="API Endpoint"
    [web_panel]="Management Panel"
    [admin_token]="Admin Token"

    # Errors
    [error_curl]="Error: curl is required"
    [error_gpu]="Warning: GPU detection failed"
    [error_network]="Network connection failed"
    [error_disk]="Insufficient disk space"

    # Confirmation
    [confirm_install]="Confirm installation?"
    [press_enter]="Press Enter to continue..."
    [yes]="Yes (Y)"
    [no]="No (N)"
)

get_text() {
    local key="$1"
    if [ "$LANGUAGE" = "cn" ]; then
        echo "${TEXT_CN[$key]}"
    else
        echo "${TEXT_EN[$key]}"
    fi
}

# ============================================================
# 变量
# ============================================================
HAS_PUBLIC_IP=0
HAS_GPU=0
GPU_VRAM=0
PUBLIC_IP=""
INSTALL_MODE=""
ADMIN_TOKEN=""
MODEL_URL=""
CDN_PORT=8080
API_PORT=11434

# ============================================================
# 检查依赖
# ============================================================
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}$(get_text error_curl)${NC}"
        echo "sudo apt install curl"
        exit 1
    fi
}

# ============================================================
# 检测公网 IP
# ============================================================
detect_public_ip() {
    echo -e "\n${YELLOW}$(get_text detecting_ip)${NC}"

    # 尝试多个IP检测服务
    local ips=()

    if PUBLIC_IP=$(curl -s -4 --max-time 5 https://api.ipify.org 2>/dev/null); then
        if [[ $PUBLIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            HAS_PUBLIC_IP=1
            echo -e "${GREEN}  $(get_text public_ip): $PUBLIC_IP${NC}"
            return 0
        fi
    fi

    if PUBLIC_IP=$(curl -s -4 --max-time 5 https://ifconfig.me 2>/dev/null); then
        if [[ $PUBLIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            HAS_PUBLIC_IP=1
            echo -e "${GREEN}  $(get_text public_ip): $PUBLIC_IP${NC}"
            return 0
        fi
    fi

    echo -e "${YELLOW}  $(get_text no_public_ip)${NC}"
    HAS_PUBLIC_IP=0
    return 1
}

# ============================================================
# 检测 GPU/算力
# ============================================================
detect_gpu() {
    echo -e "\n${YELLOW}$(get_text detecting_gpu)${NC}"

    # 检查 NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            HAS_GPU=1
            GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
            echo -e "${GREEN}  $(get_text gpu_detected)${NC}"
            echo -e "${GREEN}  $(get_text vram): ${GPU_VRAM}MB${NC}"
            return 0
        fi
    fi

    # 检查 AMD GPU
    if command -v rocm-smi &> /dev/null; then
        HAS_GPU=1
        echo -e "${GREEN}  $(get_text gpu_detected) (AMD)${NC}"
        return 0
    fi

    # 检查 Apple Silicon
    if command -v system_profiler &> /dev/null; then
        if system_profiler SPHardwareDataType 2>/dev/null | grep -q "Apple"; then
            HAS_GPU=1
            echo -e "${GREEN}  Apple Silicon GPU detected${NC}"
            return 0
        fi
    fi

    # 检查可用内存（作为备用算力指标）
    local mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_kb / 1024 / 1024))

    if [ $mem_gb -ge 8 ]; then
        echo -e "${YELLOW}  $(get_text memory): ${mem_gb}GB (CPU mode)${NC}"
        # 有足够内存也可以运行CPU模式
        return 0
    fi

    echo -e "${YELLOW}  $(get_text no_gpu)${NC}"
    HAS_GPU=0
    return 1
}

# ============================================================
# 确定安装模式
# ============================================================
determine_install_mode() {
    echo -e "\n${CYAN}$(get_text title)${NC}"
    echo -e "${CYAN}  $(get_text install_mode)${NC}"
    echo -e "${CYAN}$(get_text title)${NC}"
    echo ""

    local mode_desc=""

    if [ $HAS_PUBLIC_IP -eq 1 ] && [ $HAS_GPU -eq 1 ]; then
        mode_desc="mode_cdn_full"
    elif [ $HAS_PUBLIC_IP -eq 1 ]; then
        mode_desc="mode_cdn_proxy"
    elif [ $HAS_GPU -eq 1 ]; then
        mode_desc="mode_compute"
    else
        mode_desc="mode_light"
    fi

    echo -e "  ${GREEN}* $(get_text auto_detect): $(get_text $mode_desc)${NC}"
    echo ""
    echo "  1) $(get_text mode_cdn_full)"
    echo "  2) $(get_text mode_cdn_proxy)"
    echo "  3) $(get_text mode_compute)"
    echo "  4) $(get_text mode_light)"
    echo ""

    read -p "$(get_text input_prompt)" choice

    case $choice in
        1) INSTALL_MODE="cdn_full" ;;
        2) INSTALL_MODE="cdn_proxy" ;;
        3) INSTALL_MODE="compute" ;;
        4) INSTALL_MODE="light" ;;
        *) INSTALL_MODE=$(echo $mode_desc | sed 's/mode_//') ;;
    esac

    echo -e "${GREEN}  Selected: $INSTALL_MODE${NC}"
}

# ============================================================
# 创建目录结构
# ============================================================
create_directories() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$MODEL_DIR"
    mkdir -p "$INSTALL_DIR/web"
    mkdir -p "$INSTALL_DIR/cdn"
}

# ============================================================
# 下载模型（自动选择最快源）
# ============================================================
download_model() {
    local model_name="$1"
    local model_path="$MODEL_DIR/$model_name"

    if [ -f "$model_path" ]; then
        echo -e "${GREEN}  Model already exists: $model_name${NC}"
        return 0
    fi

    echo -e "\n${YELLOW}$(get_text installing_model)${NC}"

    # 模型URL
    local hf_url="https://huggingface.co/shenwenAI/shenwen-coderV2-GGUF/resolve/main/$model_name"
    local mirror_url="https://hf-mirror.com/shenwenAI/shenwen-coderV2-GGUF/resolve/main/$model_name"

    echo -e "${CYAN}  $(get_text trying_hf)${NC}"

    # 测试下载速度
    local speed_hf=$(curl -s -w "%{speed_download}" -o /dev/null "$hf_url" --max-time 10 2>/dev/null || echo "0")
    echo "    HF Speed: $speed_hf bytes/s"

    echo -e "${CYAN}  $(get_text trying_mirror)${NC}"
    local speed_mirror=$(curl -s -w "%{speed_download}" -o /dev/null "$mirror_url" --max-time 10 2>/dev/null || echo "0")
    echo "    Mirror Speed: $speed_mirror bytes/s"

    # 选择更快的源
    local use_url=""
    if [ "${speed_hf%.*}" -gt "${speed_mirror%.*}" ]; then
        use_url="$hf_url"
        echo -e "${GREEN}  Using HuggingFace (faster)${NC}"
    else
        use_url="$mirror_url"
        echo -e "${GREEN}  Using mirror (faster)${NC}"
    fi

    echo -e "${CYAN}  $(get_text downloading)${NC}"
    echo "    URL: $use_url"

    # 下载模型
    if curl -L --progress-bar "$use_url" -o "$model_path"; then
        echo -e "${GREEN}  $(get_text download_complete)${NC}"
        return 0
    else
        echo -e "${RED}  $(get_text download_failed)${NC}"
        rm -f "$model_path"
        return 1
    fi
}

# ============================================================
# 安装 swlm.cpp
# ============================================================
install_swlm() {
    echo -e "\n${YELLOW}$(get_text installing_swlm)${NC}"

    # 检测平台
    local os=$(uname -s)
    local arch=$(uname -m)

    echo "  Platform: $os $arch"

    # 下载预编译二进制或从源码编译
    # 这里使用占位符，实际实现需要根据swlm.cpp的发布方式调整
    cd "$INSTALL_DIR"

    if command -v git &> /dev/null; then
        # 克隆或更新swlm.cpp
        if [ -d "swlm.cpp" ]; then
            cd swlm.cpp && git pull
        else
            git clone https://github.com/shenwenAI/swlm.cpp.git
        fi

        # 编译
        cd swlm.cpp
        mkdir -p build
        cd build
        cmake ..
        make -j$(nproc)

        echo -e "${GREEN}  swlm.cpp installed successfully${NC}"
    else
        echo -e "${RED}  git is required to build swlm.cpp${NC}"
        return 1
    fi
}

# ============================================================
# 安装 CDN 服务
# ============================================================
install_cdn_service() {
    echo -e "\n${YELLOW}$(get_text installing_cdn)${NC}"

    # 创建CDN服务配置
    cat > "$CONFIG_DIR/cdn.conf" << EOF
# CDN Network Configuration
NODE_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
PUBLIC_IP=$PUBLIC_IP
CDN_PORT=$CDN_PORT
API_PORT=$API_PORT
INSTALL_MODE=$INSTALL_MODE
ADMIN_TOKEN=$ADMIN_TOKEN
MODEL_PATH=$MODEL_DIR
EOF

    # 创建CDN服务脚本
    cat > "$INSTALL_DIR/cdn/server.sh" << 'CDNSERVER'
#!/bin/bash
# CDN Server Node Service

CONFIG_DIR="/etc/cdn-network"
LOG_DIR="/var/log/cdn-network"

source "$CONFIG_DIR/cdn.conf"

echo "Starting CDN Server Node..."
echo "Node ID: $NODE_ID"
echo "Public IP: $PUBLIC_IP"
echo "CDN Port: $CDN_PORT"
echo "API Port: $API_PORT"

# 启动简单的API代理服务
# 实际实现需要更复杂的CDN逻辑
cd "$INSTALL_DIR"

# 如果有swlm，使用swlm
if [ -f "swlm.cpp/build/bin/swlm" ]; then
    echo "Starting swlm with CDN mode..."
    ./swlm.cpp/build/bin/swlm serve \
        --model "$MODEL_PATH" \
        --port $API_PORT \
        --cdn-enable \
        --cdn-port $CDN_PORT \
        --public-ip $PUBLIC_IP
else
    # 仅作为CDN代理
    echo "Starting as CDN proxy only..."
    # 使用nginx或其他反向代理
    while true; do
        sleep 1
    done
fi
CDNSERVER

    chmod +x "$INSTALL_DIR/cdn/server.sh"

    echo -e "${GREEN}  CDN service configured${NC}"
}

# ============================================================
# 安装计算节点服务
# ============================================================
install_compute_service() {
    echo -e "\n${YELLOW}$(get_text installing_cdn) (Compute Node)${NC}"

    # 创建计算节点配置
    cat > "$CONFIG_DIR/compute.conf" << EOF
# Compute Node Configuration
NODE_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
INSTALL_MODE=compute
ADMIN_TOKEN=$ADMIN_TOKEN
MODEL_PATH=$MODEL_DIR
API_PORT=$API_PORT
EOF

    # 获取CDN服务器列表
    echo -e "${CYAN}  Fetching CDN server list...${NC}"
    local cdn_list=$(curl -s --max-time 10 "$CDN_LIST_URL" 2>/dev/null || echo "[]")

    # 创建计算节点服务脚本
    cat > "$INSTALL_DIR/compute/node.sh" << 'COMPUTESERVER'
#!/bin/bash
# Compute Node Service - Redirects API to CDN

CONFIG_DIR="/etc/cdn-network"
LOG_DIR="/var/log/cdn-network"

source "$CONFIG_DIR/compute.conf"

echo "Starting Compute Node..."
echo "Node ID: $NODE_ID"
echo "Mode: Compute (will connect to CDN)"

# 如果有swlm，启动本地推理
if [ -f "$INSTALL_DIR/swlm.cpp/build/bin/swlm" ]; then
    echo "Starting local swlm inference..."
    "$INSTALL_DIR/swlm.cpp/build/bin/swlm" serve \
        --model "$MODEL_PATH" \
        --port $API_PORT \
        --compute-mode \
        --cdn-list "$cdn_list"
else
    # 仅作为API代理
    echo "Starting as API proxy..."
fi
COMPUTESERVER

    chmod +x "$INSTALL_DIR/compute/node.sh"

    echo -e "${GREEN}  Compute node configured${NC}"
}

# ============================================================
# 安装管理网页
# ============================================================
install_web_panel() {
    echo -e "\n${YELLOW}$(get_text installing_web)${NC}"

    # 创建网页目录
    local web_dir="$INSTALL_DIR/web"

    # 创建index.html
    cat > "$web_dir/index.html" << 'WEBINDEX'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CDN Network Management</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; color: white; padding: 40px 0; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { opacity: 0.9; }
        .card { background: white; border-radius: 16px; padding: 24px; margin-bottom: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.1); }
        .card h2 { color: #333; margin-bottom: 20px; font-size: 1.3em; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; }
        .status-item { background: #f8f9fa; padding: 16px; border-radius: 8px; text-align: center; }
        .status-item .value { font-size: 2em; font-weight: bold; color: #667eea; }
        .status-item .label { color: #666; margin-top: 8px; }
        .btn { display: inline-block; padding: 12px 24px; background: #667eea; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 1em; transition: transform 0.2s, box-shadow 0.2s; text-decoration: none; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(102,126,234,0.4); }
        .btn-danger { background: #e74c3c; }
        .btn-success { background: #2ecc71; }
        .server-list { max-height: 400px; overflow-y: auto; }
        .server-item { display: flex; justify-content: space-between; align-items: center; padding: 12px; background: #f8f9fa; border-radius: 8px; margin-bottom: 8px; }
        .server-item .info { flex: 1; }
        .server-item .ip { font-weight: bold; }
        .server-item .latency { color: #2ecc71; font-size: 0.9em; }
        .server-item .status { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 8px; }
        .status-online { background: #2ecc71; }
        .status-offline { background: #e74c3c; }
        .logs { background: #1e1e1e; color: #d4d4d4; padding: 16px; border-radius: 8px; font-family: 'Monaco', 'Menlo', monospace; font-size: 0.85em; max-height: 300px; overflow-y: auto; }
        .logs .log-line { margin-bottom: 4px; }
        .logs .log-time { color: #888; }
        .logs .log-info { color: #4fc3f7; }
        .logs .log-warn { color: #ffb74d; }
        .logs .log-error { color: #ef5350; }
        .tabs { display: flex; gap: 8px; margin-bottom: 16px; }
        .tab { padding: 10px 20px; background: #f8f9fa; border: none; border-radius: 8px; cursor: pointer; }
        .tab.active { background: #667eea; color: white; }
        .config-form { display: grid; gap: 16px; }
        .form-group { display: flex; flex-direction: column; gap: 4px; }
        .form-group label { font-weight: 500; color: #333; }
        .form-group input, .form-group select { padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-size: 1em; }
        .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); justify-content: center; align-items: center; z-index: 1000; }
        .modal.show { display: flex; }
        .modal-content { background: white; padding: 24px; border-radius: 16px; max-width: 500px; width: 90%; }
        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
        .modal-close { background: none; border: none; font-size: 1.5em; cursor: pointer; }
        .api-docs { background: #f8f9fa; padding: 16px; border-radius: 8px; }
        .api-docs code { background: #e9ecef; padding: 2px 6px; border-radius: 4px; font-family: monospace; }
        .api-docs pre { background: #2d2d2d; color: #f8f8f2; padding: 16px; border-radius: 8px; overflow-x: auto; margin-top: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>CDN Network Manager</h1>
            <p>Distributed AI Inference Network</p>
        </div>

        <div class="tabs">
            <button class="tab active" onclick="showTab('dashboard')">Dashboard</button>
            <button class="tab" onclick="showTab('servers')">CDN Servers</button>
            <button class="tab" onclick="showTab('config')">Configuration</button>
            <button class="tab" onclick="showTab('logs')">Logs</button>
            <button class="tab" onclick="showTab('api')">API</button>
        </div>

        <div id="tab-dashboard" class="tab-content">
            <div class="card">
                <h2>System Status</h2>
                <div class="status-grid">
                    <div class="status-item">
                        <div class="value" id="node-status">-</div>
                        <div class="label">Node Status</div>
                    </div>
                    <div class="status-item">
                        <div class="value" id="public-ip">-</div>
                        <div class="label">Public IP</div>
                    </div>
                    <div class="status-item">
                        <div class="value" id="connected-nodes">0</div>
                        <div class="label">Connected Nodes</div>
                    </div>
                    <div class="status-item">
                        <div class="value" id="requests-today">0</div>
                        <div class="label">Requests Today</div>
                    </div>
                </div>
            </div>

            <div class="card">
                <h2>Quick Actions</h2>
                <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                    <button class="btn btn-success" onclick="startService()">Start</button>
                    <button class="btn btn-danger" onclick="stopService()">Stop</button>
                    <button class="btn" onclick="restartService()">Restart</button>
                    <button class="btn" onclick="refreshStatus()">Refresh</button>
                </div>
            </div>
        </div>

        <div id="tab-servers" class="tab-content" style="display:none;">
            <div class="card">
                <h2>CDN Servers</h2>
                <div class="server-list" id="server-list">
                    <div class="server-item">
                        <span class="status status-offline"></span>
                        <div class="info">
                            <div class="ip">Loading...</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <h2>Actions</h2>
                <div style="display: flex; gap: 12px;">
                    <button class="btn" onclick="refreshServers()">Refresh List</button>
                    <button class="btn" onclick="showAddServer()">Add Server</button>
                </div>
            </div>
        </div>

        <div id="tab-config" class="tab-content" style="display:none;">
            <div class="card">
                <h2>Configuration</h2>
                <div class="config-form">
                    <div class="form-group">
                        <label>Admin Token</label>
                        <input type="password" id="admin-token" placeholder="Enter admin token">
                    </div>
                    <div class="form-group">
                        <label>CDN Port</label>
                        <input type="number" id="cdn-port" value="8080">
                    </div>
                    <div class="form-group">
                        <label>API Port</label>
                        <input type="number" id="api-port" value="11434">
                    </div>
                    <button class="btn" onclick="saveConfig()">Save Configuration</button>
                </div>
            </div>
        </div>

        <div id="tab-logs" class="tab-content" style="display:none;">
            <div class="card">
                <h2>System Logs</h2>
                <div class="logs" id="log-container">
                    <div class="log-line"><span class="log-time">[System]</span> Loading logs...</div>
                </div>
                <div style="margin-top: 12px;">
                    <button class="btn" onclick="clearLogs()">Clear</button>
                    <button class="btn" onclick="refreshLogs()">Refresh</button>
                </div>
            </div>
        </div>

        <div id="tab-api" class="tab-content" style="display:none;">
            <div class="card">
                <h2>API Documentation</h2>
                <div class="api-docs">
                    <h3>Endpoints</h3>
                    <p><code>POST /api/v1/completions</code> - Text completion</p>
                    <p><code>POST /api/v1/embeddings</code> - Get embeddings</p>
                    <p><code>GET /api/v1/models</code> - List available models</p>

                    <h3 style="margin-top:16px;">Example Request</h3>
                    <pre>
curl -X POST http://localhost:11434/api/v1/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "model": "shenwen-coderV2",
    "prompt": "Hello, how are you?",
    "max_tokens": 100
  }'</pre>
                </div>
            </div>
        </div>
    </div>

    <!-- Add Server Modal -->
    <div class="modal" id="add-server-modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Add CDN Server</h2>
                <button class="modal-close" onclick="hideAddServer()">&times;</button>
            </div>
            <div class="config-form">
                <div class="form-group">
                    <label>Server URL</label>
                    <input type="text" id="new-server-url" placeholder="https://cdn.example.com">
                </div>
                <button class="btn" onclick="addServer()">Add</button>
            </div>
        </div>
    </div>

    <script>
        // Tab management
        function showTab(tabName) {
            document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
            document.querySelectorAll('.tab').forEach(el => el.classList.remove('active'));
            document.getElementById('tab-' + tabName).style.display = 'block';
            event.target.classList.add('active');
        }

        // Load status
        async function refreshStatus() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();
                document.getElementById('node-status').textContent = data.status || 'Unknown';
                document.getElementById('public-ip').textContent = data.public_ip || 'N/A';
            } catch (e) {
                console.error('Failed to load status:', e);
            }
        }

        // Load servers
        async function refreshServers() {
            try {
                const res = await fetch('/api/cdn/servers');
                const servers = await res.json();
                const list = document.getElementById('server-list');
                list.innerHTML = servers.map(s => `
                    <div class="server-item">
                        <span class="status ${s.online ? 'status-online' : 'status-offline'}"></span>
                        <div class="info">
                            <div class="ip">${s.ip}</div>
                            <div>Latency: <span class="latency">${s.latency || 'N/A'}ms</span></div>
                        </div>
                    </div>
                `).join('');
            } catch (e) {
                console.error('Failed to load servers:', e);
            }
        }

        // Logs
        async function refreshLogs() {
            try {
                const res = await fetch('/api/logs');
                const logs = await res.json();
                const container = document.getElementById('log-container');
                container.innerHTML = logs.map(l => `
                    <div class="log-line">
                        <span class="log-time">[${l.time}]</span>
                        <span class="log-${l.level}">${l.message}</span>
                    </div>
                `).join('');
            } catch (e) {
                console.error('Failed to load logs:', e);
            }
        }

        function clearLogs() {
            document.getElementById('log-container').innerHTML = '';
        }

        // Service control
        async function startService() {
            await fetch('/api/service/start', { method: 'POST' });
            refreshStatus();
        }

        async function stopService() {
            await fetch('/api/service/stop', { method: 'POST' });
            refreshStatus();
        }

        async function restartService() {
            await fetch('/api/service/restart', { method: 'POST' });
            refreshStatus();
        }

        // Config
        async function saveConfig() {
            const token = document.getElementById('admin-token').value;
            const cdnPort = document.getElementById('cdn-port').value;
            const apiPort = document.getElementById('api-port').value;

            await fetch('/api/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ token, cdnPort, apiPort })
            });
            alert('Configuration saved!');
        }

        // Server management
        function showAddServer() {
            document.getElementById('add-server-modal').classList.add('show');
        }

        function hideAddServer() {
            document.getElementById('add-server-modal').classList.remove('show');
        }

        async function addServer() {
            const url = document.getElementById('new-server-url').value;
            await fetch('/api/cdn/servers', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url })
            });
            hideAddServer();
            refreshServers();
        }

        // Initialize
        refreshStatus();
        refreshServers();
        refreshLogs();
    </script>
</body>
</html>
WEBINDEX

    echo -e "${GREEN}  Web panel created at $web_dir${NC}"
}

# ============================================================
# 生成管理脚本
# ============================================================
create_management_script() {
    echo -e "\n${CYAN}Creating management script...${NC}"

    cat > "$INSTALL_DIR/cdn-manage.sh" << 'MANAGESCRIPT'
#!/bin/bash
# CDN Network Management Script
# Usage: ./cdn-manage.sh [command]

INSTALL_DIR="/opt/cdn-network"
CONFIG_DIR="/etc/cdn-network"
LOG_DIR="/var/log/cdn-network"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_status() {
    echo -e "\n${BLUE}=== CDN Network Status ===${NC}"

    if [ -f "$CONFIG_DIR/cdn.conf" ]; then
        source "$CONFIG_DIR/cdn.conf"
        echo -e "Node ID: ${GREEN}$NODE_ID${NC}"
        echo -e "Public IP: ${GREEN}${PUBLIC_IP:-N/A}${NC}"
        echo -e "Install Mode: ${GREEN}$INSTALL_MODE${NC}"
        echo -e "CDN Port: ${GREEN}$CDN_PORT${NC}"
        echo -e "API Port: ${GREEN}$API_PORT${NC}"
    else
        echo -e "${RED}Not configured${NC}"
    fi

    echo ""
    echo -e "${BLUE}=== Service Status ===${NC}"
    if pgrep -f "swlm" > /dev/null; then
        echo -e "swlm service: ${GREEN}Running${NC}"
    else
        echo -e "swlm service: ${RED}Stopped${NC}"
    fi
}

start_services() {
    echo -e "\n${YELLOW}Starting services...${NC}"

    if [ -f "$CONFIG_DIR/cdn.conf" ]; then
        source "$CONFIG_DIR/cdn.conf"

        if [ "$INSTALL_MODE" = "cdn_full" ] || [ "$INSTALL_MODE" = "cdn_proxy" ]; then
            "$INSTALL_DIR/cdn/server.sh" &
            echo -e "${GREEN}CDN server started${NC}"
        fi

        if [ "$INSTALL_MODE" = "compute" ]; then
            "$INSTALL_DIR/compute/node.sh" &
            echo -e "${GREEN}Compute node started${NC}"
        fi
    fi
}

stop_services() {
    echo -e "\n${YELLOW}Stopping services...${NC}"
    pkill -f "swlm" 2>/dev/null
    pkill -f "cdn" 2>/dev/null
    echo -e "${GREEN}Services stopped${NC}"
}

show_logs() {
    echo -e "\n${BLUE}=== Recent Logs ===${NC}"
    if [ -f "$LOG_DIR/cdn.log" ]; then
        tail -50 "$LOG_DIR/cdn.log"
    else
        echo -e "${YELLOW}No logs found${NC}"
    fi
}

list_cdn_servers() {
    echo -e "\n${BLUE}=== CDN Servers ===${NC}"
    echo -e "${YELLOW}Fetching from network...${NC}"

    curl -s "https://raw.githubusercontent.com/shenwenAI/Calculate-cdn.sh/main/cdn-list.json" 2>/dev/null | \
        python3 -c "import sys,json; [print(f\"{s['name']}: {s['url']}\") for s in json.load(sys.stdin).get('servers',[])]" 2>/dev/null || \
        echo -e "${RED}Failed to fetch CDN list${NC}"
}

case "${1:-status}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    servers)
        list_cdn_servers
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|servers}"
        echo ""
        echo "Commands:"
        echo "  start    - Start CDN network services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart services"
        echo "  status   - Show current status"
        echo "  logs     - Show recent logs"
        echo "  servers  - List CDN servers"
        exit 1
        ;;
esac
MANAGESCRIPT

    chmod +x "$INSTALL_DIR/cdn-manage.sh"
    echo -e "${GREEN}Management script created: $INSTALL_DIR/cdn-manage.sh${NC}"
}

# ============================================================
# 创建系统服务
# ============================================================
create_systemd_service() {
    echo -e "\n${CYAN}Creating systemd service...${NC}"

    # 创建systemd服务文件
    cat > "/tmp/cdn-network.service" << EOF
[Unit]
Description=CDN Network Service
After=network.target

[Service]
Type=forking
ExecStart=$INSTALL_DIR/cdn/server.sh
ExecStop=pkill -f cdn
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${YELLOW}To install as system service, run:${NC}"
    echo -e "  sudo cp /tmp/cdn-network.service /etc/systemd/system/"
    echo -e "  sudo systemctl daemon-reload"
    echo -e "  sudo systemctl enable cdn-network"
    echo -e "  sudo systemctl start cdn-network"
}

# ============================================================
# 主安装流程
# ============================================================
main_install() {
    echo -e "\n${CYAN}$(get_text title)${NC}"
    echo -e "${CYAN}$(get_text welcome)${NC}"
    echo -e "${CYAN}$(get_text author)${NC}"
    echo -e "${CYAN}$(get_text title)${NC}"

    # 语言选择
    select_language

    # 系统检测
    echo -e "\n${YELLOW}$(get_text detecting_system)${NC}"
    check_dependencies
    detect_public_ip
    detect_gpu

    # 确定安装模式
    determine_install_mode

    # 确认安装
    echo ""
    read -p "$(get_text confirm_install) (Y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]] && [ ! -z "$confirm" ]; then
        echo -e "${RED}Installation cancelled${NC}"
        exit 0
    fi

    # 生成管理员令牌
    ADMIN_TOKEN=$(openssl rand -base64 32 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    echo -e "${GREEN}Admin Token: $ADMIN_TOKEN${NC}"

    # 创建目录
    echo -e "\n${YELLOW}$(get_text installing)${NC}"
    create_directories

    # 根据安装模式执行
    case $INSTALL_MODE in
        cdn_full)
            echo -e "\n${GREEN}Mode: Full CDN Node${NC}"
            install_cdn_service
            install_swlm

            # 选择模型
            echo -e "\n${CYAN}$(get_text select_model)${NC}"
            echo "1) Q4_K_M (4GB, Fast)"
            echo "2) Q5_K_M (6GB, Balanced)"
            echo "3) Q8_0 (12GB, High Quality)"
            read -p "Select (1-3): " model_choice
            case $model_choice in
                1) download_model "shenwen-coderV2-Q4_K_M.gguf" ;;
                2) download_model "shenwen-coderV2-Q5_K_M.gguf" ;;
                *) download_model "shenwen-coderV2-Q4_K_M.gguf" ;;
            esac

            install_web_panel
            ;;
        cdn_proxy)
            echo -e "\n${GREEN}Mode: CDN Proxy (No compute)${NC}"
            install_cdn_service
            install_web_panel
            ;;
        compute)
            echo -e "\n${GREEN}Mode: Compute Node${NC}"
            install_compute_service
            install_swlm
            download_model "shenwen-coderV2-Q4_K_M.gguf"
            ;;
        light)
            echo -e "\n${GREEN}Mode: Light Node${NC}"
            echo -e "${YELLOW}Installing as lightweight CDN relay...${NC}"
            install_cdn_service
            ;;
    esac

    # 创建管理脚本
    create_management_script
    create_systemd_service

    # 完成
    echo -e "\n${GREEN}$(get_text title)${NC}"
    echo -e "${GREEN}$(get_text install_complete)${NC}"
    echo -e "${GREEN}$(get_text title)${NC}"
    echo ""
    echo -e "${CYAN}Management Script: ${GREEN}$INSTALL_DIR/cdn-manage.sh${NC}"
    echo -e "${CYAN}Web Panel: ${GREEN}http://localhost:8080${NC}"
    echo -e "${CYAN}Admin Token: ${GREEN}$ADMIN_TOKEN${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $INSTALL_DIR/cdn-manage.sh start   # Start services"
    echo "  $INSTALL_DIR/cdn-manage.sh stop    # Stop services"
    echo "  $INSTALL_DIR/cdn-manage.sh status  # Check status"
    echo "  $INSTALL_DIR/cdn-manage.sh logs    # View logs"
    echo ""
}

# ============================================================
# 语言选择
# ============================================================
select_language() {
    echo ""
    echo -e "${CYAN}$(get_text title)${NC}"
    echo -e "${CYAN}$(get_text welcome)${NC}"
    echo -e "${CYAN}$(get_text author)${NC}"
    echo -e "${CYAN}$(get_text title)${NC}"
    echo ""
    echo -e "${YELLOW}$(get_text select_lang)${NC}"
    echo -e "  $(get_text option_cn)"
    echo -e "  $(get_text option_en)"
    echo ""

    while true; do
        read -p "$(get_text input_prompt)" choice
        case $choice in
            1)
                LANGUAGE="cn"
                break
                ;;
            2)
                LANGUAGE="en"
                break
                ;;
            *)
                echo -e "${RED}$(get_text invalid_input)${NC}"
                ;;
        esac
    done
}

# 运行主函数
main_install "$@"
