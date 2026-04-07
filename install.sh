#!/bin/bash
# ============================================================
# shenwenCDN 分布式智能部署系统
# 自动检测网络环境和硬件配置，智能分配节点角色
# 作者：shenwenAI Team
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
LANGUAGE="zh"
WORKER_URL="https://shenwencdn.578388.xyz"
INSTALL_DIR="/opt/swllm.cpp"
NODE_ROLE=""
PUBLIC_IP=""
CPU_CORES=0
MEMORY_GB=0
HAS_GPU=false
MODEL_URL=""

# ============================================================
# 语言选择
# ============================================================
choose_language() {
    echo -e "${BLUE}请选择语言 / Please choose language:${NC}"
    echo "1) 中文 (Chinese)"
    echo "2) English (英文)"
    echo -n "请输入选项 / Enter choice (1 or 2): "
    read -r choice

    case $choice in
        1) LANGUAGE="zh" ;;
        2) LANGUAGE="en" ;;
        *) 
            echo -e "${RED}无效选项 / Invalid choice${NC}"
            choose_language
            ;;
    esac
}

# 显示语言文本
show_text() {
    if [ "$LANGUAGE" = "zh" ]; then
        case $1 in
            "welcome") echo "欢迎使用 shenwenCDN 部署系统" ;;
            "checking_ip") echo "正在检测公网 IP..." ;;
            "checking_hardware") echo "正在检测硬件配置..." ;;
            "installing_deps") echo "正在安装依赖..." ;;
            "cloning_repo") echo "正在克隆仓库..." ;;
            "compiling") echo "正在编译 swllm.cpp..." ;;
            "downloading_model") echo "正在下载模型..." ;;
            "registering_node") echo "正在注册节点到 CDN 网络..." ;;
            "complete") echo "安装完成！" ;;
            "public_ip_found") echo "检测到公网 IP 地址" ;;
            "no_public_ip") echo "未检测到公网 IP 地址（内网环境）" ;;
            "powerful_hardware") echo "硬件配置强劲，可作为计算节点" ;;
            "weak_hardware") echo "硬件配置较低，仅可作为 CDN 节点" ;;
            "role_hybrid") echo "角色：混合节点（计算+CDN）" ;;
            "role_compute") echo "角色：计算节点（仅内网）" ;;
            "role_cdn") echo "角色：CDN 代理节点" ;;
            "role_none") echo "不符合任何节点条件，终止安装" ;;
            "press_enter") echo "按回车键继续..." ;;
            "error") echo "错误" ;;
            "success") echo "成功" ;;
        esac
    else
        case $1 in
            "welcome") echo "Welcome to shenwenCDN Deployment System" ;;
            "checking_ip") echo "Checking public IP..." ;;
            "checking_hardware") echo "Checking hardware configuration..." ;;
            "installing_deps") echo "Installing dependencies..." ;;
            "cloning_repo") echo "Cloning repository..." ;;
            "compiling") echo "Compiling swllm.cpp..." ;;
            "downloading_model") echo "Downloading model..." ;;
            "registering_node") echo "Registering node to CDN network..." ;;
            "complete") echo "Installation complete!" ;;
            "public_ip_found") echo "Public IP address detected" ;;
            "no_public_ip") echo "No public IP detected (private network)" ;;
            "powerful_hardware") echo "Powerful hardware, can serve as compute node" ;;
            "weak_hardware") echo "Limited hardware, can only serve as CDN node" ;;
            "role_hybrid") echo "Role: Hybrid Node (Compute + CDN)" ;;
            "role_compute") echo "Role: Compute Node (Internal only)" ;;
            "role_cdn") echo "Role: CDN Proxy Node" ;;
            "role_none") echo "Does not meet any node requirements, aborting" ;;
            "press_enter") echo "Press Enter to continue..." ;;
            "error") echo "Error" ;;
            "success") echo "Success" ;;
        esac
    fi
}

# ============================================================
# 检测公网 IP
# ============================================================
check_public_ip() {
    echo -e "\n${YELLOW}$(show_text "checking_ip")${NC}"
    
    # 获取本机所有 IP
    local ips=()
    while IFS= read -r line; do
        local ip=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
        if [ -n "$ip" ] && [[ ! "$ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.) ]]; then
            ips+=("$ip")
        fi
    done < <(ip -4 addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1")
    
    if [ ${#ips[@]} -gt 0 ]; then
        PUBLIC_IP="${ips[0]}"
        echo -e "${GREEN}✓ $(show_text "public_ip_found"): ${PUBLIC_IP}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ $(show_text "no_public_ip")${NC}"
        PUBLIC_IP=""
        return 1
    fi
}

# ============================================================
# 检测硬件配置
# ============================================================
check_hardware() {
    echo -e "\n${YELLOW}$(show_text "checking_hardware")${NC}"
    
    # CPU 核心数
    CPU_CORES=$(nproc 2>/dev/null || echo "0")
    echo "  CPU 核心数：${CPU_CORES}"
    
    # 内存大小 (GB)
    MEMORY_GB=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")
    echo "  内存大小：${MEMORY_GB} GB"
    
    # 检测 GPU
    if command -v nvidia-smi &> /dev/null; then
        HAS_GPU=true
        echo -e "  GPU: ${GREEN}检测到 NVIDIA GPU${NC}"
    else
        HAS_GPU=false
        echo "  GPU: 未检测到"
    fi
    
    # 判断是否满足算力要求
    if [ "$MEMORY_GB" -gt 8 ] && ([ "$CPU_CORES" -gt 4 ] || [ "$HAS_GPU" = true ]); then
        echo -e "${GREEN}✓ $(show_text "powerful_hardware")${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ $(show_text "weak_hardware")${NC}"
        return 1
    fi
}

# ============================================================
# 确定节点角色
# ============================================================
determine_role() {
    local has_public=$1
    local has_power=$2
    
    if [ "$has_public" = "0" ] && [ "$has_power" = "0" ]; then
        NODE_ROLE="hybrid"
        echo -e "${GREEN}$(show_text "role_hybrid")${NC}"
    elif [ "$has_public" != "0" ] && [ "$has_power" = "0" ]; then
        NODE_ROLE="compute"
        echo -e "${BLUE}$(show_text "role_compute")${NC}"
    elif [ "$has_public" = "0" ] && [ "$has_power" != "0" ]; then
        NODE_ROLE="cdn"
        echo -e "${YELLOW}$(show_text "role_cdn")${NC}"
    else
        echo -e "${RED}✗ $(show_text "role_none")${NC}"
        exit 0
    fi
}

# ============================================================
# 安装依赖
# ============================================================
install_dependencies() {
    echo -e "\n${YELLOW}$(show_text "installing_deps")${NC}"
    
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y git cmake build-essential curl wget libcurl4-openssl-dev
    elif command -v yum &> /dev/null; then
        sudo yum install -y git cmake gcc gcc-c++ curl wget libcurl-devel
    else
        echo -e "${RED}$(show_text "error"): 不支持的包管理器${NC}"
        exit 1
    fi
}

# ============================================================
# 测试下载速度并选择最快源
# ============================================================
test_download_speed() {
    echo -e "\n${YELLOW}正在测试下载源速度...${NC}"
    
    local url1="https://huggingface.co/shenwenAI/shenwen-coderV2-GGUF/resolve/main/shenwen-coderV2-Q4_K_M.gguf?download=true"
    local url2="https://hf-mirror.com/shenwenAI/shenwen-coderV2-GGUF/resolve/main/shenwen-coderV2-Q4_K_M.gguf?download=true"
    
    # 测试 HuggingFace
    local time1=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 5 -m 10 "$url1" 2>&1 || echo "999")
    echo "  HuggingFace: ${time1}s"
    
    # 测试镜像站
    local time2=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 5 -m 10 "$url2" 2>&1 || echo "999")
    echo "  HF-Mirror: ${time2}s"
    
    # 选择更快的
    if (( $(echo "$time1 < $time2" | bc -l 2>/dev/null || echo 0) )); then
        MODEL_URL="$url1"
        echo -e "${GREEN}选择：HuggingFace (原始站)${NC}"
    else
        MODEL_URL="$url2"
        echo -e "${GREEN}选择：HF-Mirror (镜像站)${NC}"
    fi
}

# ============================================================
# 克隆并编译 swllm.cpp
# ============================================================
compile_swllm() {
    if [ "$NODE_ROLE" = "cdn" ]; then
        echo -e "\n${YELLOW}CDN 节点不需要编译 swllm.cpp，跳过...${NC}"
        return 0
    fi
    
    echo -e "\n${YELLOW}$(show_text "cloning_repo")${NC}"
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if [ ! -d "swllm.cpp" ]; then
        git clone https://github.com/shenwenAI/swllm.cpp.git
    fi
    
    cd swllm.cpp
    
    echo -e "\n${YELLOW}$(show_text "compiling")${NC}"
    
    # 尝试 CUDA 编译
    if [ "$HAS_GPU" = true ]; then
        echo "  尝试编译 CUDA 版本..."
        if ! cmake -B build -DGGML_CUDA=ON 2>/dev/null; then
            echo -e "${YELLOW}  CUDA 编译失败，回退到 CPU 版本${NC}"
            cmake -B build
        fi
    else
        cmake -B build
    fi
    
    cmake --build build --config Release -j$(nproc)
    
    echo -e "${GREEN}✓ 编译完成${NC}"
}

# ============================================================
# 下载模型
# ============================================================
download_model() {
    if [ "$NODE_ROLE" = "cdn" ]; then
        echo -e "\n${YELLOW}CDN 节点不存储模型，跳过...${NC}"
        return 0
    fi
    
    echo -e "\n${YELLOW}$(show_text "downloading_model")${NC}"
    
    test_download_speed
    
    local model_path="$INSTALL_DIR/swllm.cpp/models/shenwen-coderV2-Q4_K_M.gguf"
    sudo mkdir -p "$(dirname $model_path)"
    sudo chown $USER:$USER "$(dirname $model_path)"
    
    echo "  下载链接：$MODEL_URL"
    curl -L -o "$model_path" "$MODEL_URL"
    
    echo -e "${GREEN}✓ 模型下载完成：$model_path${NC}"
}

# ============================================================
# 获取地理位置
# ============================================================
get_location() {
    local location="Unknown"
    
    if command -v curl &> /dev/null; then
        location=$(curl -s ipapi.co/country 2>/dev/null || echo "Unknown")
        if [ "$location" = "Unknown" ] || [ -z "$location" ]; then
            location=$(curl -s ipinfo.io/country 2>/dev/null || echo "Unknown")
        fi
    fi
    
    echo "$location"
}

# ============================================================
# 注册节点到 Workers
# ============================================================
register_node() {
    echo -e "\n${YELLOW}$(show_text "registering_node")${NC}"
    
    local port=8080
    local location=$(get_location)
    
    local payload="{
        \"ip\": \"${PUBLIC_IP:-127.0.0.1}\",
        \"role\": \"$NODE_ROLE\",
        \"cpu_cores\": $CPU_CORES,
        \"memory_gb\": $MEMORY_GB,
        \"has_gpu\": $HAS_GPU,
        \"location\": \"$location\",
        \"port\": $port
    }"
    
    echo "  注册信息：$payload"
    
    local response=$(curl -s -X POST "$WORKER_URL/api/register" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)
    
    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ 节点注册成功${NC}"
        
        # 启动心跳任务
        start_heartbeat
    else
        echo -e "${YELLOW}⚠ 节点注册失败，但本地服务仍可运行${NC}"
        echo "  响应：$response"
    fi
}

# ============================================================
# 启动心跳
# ============================================================
start_heartbeat() {
    local node_id="${PUBLIC_IP:-127.0.0.1}:8080"
    
    # 创建 systemd 服务或后台任务
    cat > "$INSTALL_DIR/heartbeat.sh" << 'EOF'
#!/bin/bash
WORKER_URL="https://shenwencdn.578388.xyz"
NODE_ID="{{NODE_ID}}"

while true; do
    curl -s -X POST "$WORKER_URL/api/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"nodeId\": \"$NODE_ID\"}" > /dev/null 2>&1
    sleep 300  # 每 5 分钟发送一次心跳
done
EOF
    
    sed -i "s/{{NODE_ID}}/$node_id/" "$INSTALL_DIR/heartbeat.sh"
    chmod +x "$INSTALL_DIR/heartbeat.sh"
    
    # 后台运行
    nohup "$INSTALL_DIR/heartbeat.sh" > /dev/null 2>&1 &
    echo $! > "$INSTALL_DIR/heartbeat.pid"
    
    echo "  心跳任务已启动 (PID: $(cat $INSTALL_DIR/heartbeat.pid))"
}

# ============================================================
# 生成管理脚本
# ============================================================
create_manager_script() {
    echo -e "\n${YELLOW}创建管理脚本...${NC}"
    
    cat > "$INSTALL_DIR/swllm-manager.sh" << 'EOF'
#!/bin/bash
# swllm.cpp 管理脚本

SERVICE_NAME="swllm-api"
INSTALL_DIR="/opt/swllm.cpp"

case "$1" in
    start)
        echo "启动 swllm.cpp API 服务..."
        if [ -f "$INSTALL_DIR/swllm.cpp/build/bin/server" ]; then
            cd "$INSTALL_DIR/swllm.cpp"
            nohup ./build/bin/server -m models/shenwen-coderV2-Q4_K_M.gguf --host 0.0.0.0 --port 8080 > /var/log/swllm.log 2>&1 &
            echo $! > "$INSTALL_DIR/server.pid"
            echo "服务已启动 (PID: $(cat $INSTALL_DIR/server.pid))"
        else
            echo "错误：未找到编译后的 server 程序"
            exit 1
        fi
        ;;
    stop)
        echo "停止服务..."
        if [ -f "$INSTALL_DIR/server.pid" ]; then
            kill $(cat $INSTALL_DIR/server.pid) 2>/dev/null
            rm -f "$INSTALL_DIR/server.pid"
            echo "服务已停止"
        else
            echo "服务未运行"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if [ -f "$INSTALL_DIR/server.pid" ] && ps -p $(cat $INSTALL_DIR/server.pid) > /dev/null 2>&1; then
            echo "服务运行中 (PID: $(cat $INSTALL_DIR/server.pid))"
        else
            echo "服务未运行"
        fi
        ;;
    *)
        echo "用法：$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/swllm-manager.sh"
    echo -e "${GREEN}✓ 管理脚本已创建：$INSTALL_DIR/swllm-manager.sh${NC}"
}

# ============================================================
# 启动服务
# ============================================================
start_service() {
    if [ "$NODE_ROLE" = "cdn" ]; then
        echo -e "\n${YELLOW}CDN 节点无需启动本地 API 服务${NC}"
        return 0
    fi
    
    echo -e "\n${YELLOW}启动 swllm.cpp API 服务...${NC}"
    
    cd "$INSTALL_DIR/swllm.cpp"
    
    # 根据角色决定监听地址
    local listen_host="127.0.0.1"
    if [ "$NODE_ROLE" = "hybrid" ]; then
        listen_host="0.0.0.0"  # 混合节点需要对外服务
    fi
    
    nohup ./build/bin/server \
        -m models/shenwen-coderV2-Q4_K_M.gguf \
        --host "$listen_host" \
        --port 8080 \
        > /var/log/swllm.log 2>&1 &
    
    echo $! > "$INSTALL_DIR/server.pid"
    echo -e "${GREEN}✓ 服务已启动 (PID: $(cat $INSTALL_DIR/server.pid))${NC}"
    echo -e "${BLUE}  API 地址：http://${listen_host}:8080${NC}"
}

# ============================================================
# 主函数
# ============================================================
main() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}        $(show_text "welcome")${NC}"
    echo -e "${BLUE}============================================================${NC}"
    
    choose_language
    
    # 检测阶段
    check_public_ip
    local ip_result=$?
    
    check_hardware
    local hw_result=$?
    
    determine_role $ip_result $hw_result
    
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}  开始部署...${NC}"
    echo -e "${BLUE}============================================================${NC}"
    
    # 安装依赖
    install_dependencies
    
    # 编译和下载
    compile_swllm
    download_model
    
    # 注册和启动
    register_node
    create_manager_script
    start_service
    
    echo -e "\n${GREEN}============================================================${NC}"
    echo -e "${GREEN}  ✓ $(show_text "complete")${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo "  安装目录：$INSTALL_DIR"
    echo "  管理脚本：$INSTALL_DIR/swllm-manager.sh"
    echo "  节点角色：$NODE_ROLE"
    echo ""
    echo "  常用命令:"
    echo "    sudo $INSTALL_DIR/swllm-manager.sh start   # 启动服务"
    echo "    sudo $INSTALL_DIR/swllm-manager.sh stop    # 停止服务"
    echo "    sudo $INSTALL_DIR/swllm-manager.sh status  # 查看状态"
    echo ""
    echo "  访问监控面板：https://shenwencdn.578388.xyz"
    echo ""
}

# 运行主函数
main "$@"
