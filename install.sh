#!/bin/bash
# ============================================================
# 安装启动脚本 - 支持中英文选择
# 作者：shc
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认语言
LANGUAGE="en"

# ============================================================
# 多语言文本
# ============================================================
declare -A TEXT_CN
declare -A TEXT_EN

# 中文文本
TEXT_CN=(
    [title]="============================================================"
    [welcome]="        欢迎使用安装程序"
    [author]="        作者：shc"
    [select_lang]="请选择语言 / Please select language:"
    [option_cn]="1) 中文 (Chinese)"
    [option_en]="2) English (英文)"
    [input_prompt]="请输入选项 (1-2): "
    [invalid_input]="无效输入，请重新选择"
    [checking_ip]="📍 正在检测本机公网 IP 地址..."
    [ip_check_title]="公网 IP 检测"
    [public_ip_found]="✅ 检测到公网 IP 地址"
    [no_public_ip]="❌ 未检测到公网 IP 地址"
    [start_install]="开始安装..."
    [press_enter]="按回车键继续..."
    [error_curl]="错误：需要安装 curl"
    [install_curl]="请运行：sudo apt install curl 或 sudo yum install curl"
    [ipv4_test]="IPv4 地址测试"
    [ipv6_test]="IPv6 地址测试"
    [total]="总数"
    [public]="公网"
    [private]="私有/不可达"
    [summary]="测试结果总结"
    [testing]="测试"
    [private_addr]="私有地址 (跳过公网测试)"
    [public_ip_ok]="✅ 公网 IP"
    [nat_behind]="⚠️  NAT 后方 (非直接公网)"
    [test_failed]="❌ 测试失败 (可能无公网)"
    [no_ipv4]="未找到 IPv4 地址"
    [no_ipv6]="未找到 IPv6 地址"
)

# English text
TEXT_EN=(
    [title]="============================================================"
    [welcome]="        Welcome to Installation Program"
    [author]="        Author: shc"
    [select_lang]="请选择语言 / Please select language:"
    [option_cn]="1) 中文 (Chinese)"
    [option_en]="2) English (英文)"
    [input_prompt]="Please enter option (1-2): "
    [invalid_input]="Invalid input, please select again"
    [checking_ip]="📍 Checking public IP address..."
    [ip_check_title]="Public IP Detection"
    [public_ip_found]="✅ Public IP detected"
    [no_public_ip]="❌ No public IP detected"
    [start_install]="Starting installation..."
    [press_enter]="Press Enter to continue..."
    [error_curl]="Error: curl is required"
    [install_curl]="Please run: sudo apt install curl or sudo yum install curl"
    [ipv4_test]="IPv4 Address Test"
    [ipv6_test]="IPv6 Address Test"
    [total]="Total"
    [public]="Public"
    [private]="Private/Unreachable"
    [summary]="Test Summary"
    [testing]="Testing"
    [private_addr]="Private address (skip public test)"
    [public_ip_ok]="✅ Public IP"
    [nat_behind]="⚠️  Behind NAT (not direct public)"
    [test_failed]="❌ Test failed (may not be public)"
    [no_ipv4]="No IPv4 address found"
    [no_ipv6]="No IPv6 address found"
)

# 获取文本函数
get_text() {
    local key="$1"
    if [ "$LANGUAGE" = "cn" ]; then
        echo "${TEXT_CN[$key]}"
    else
        echo "${TEXT_EN[$key]}"
    fi
}

# ============================================================
# 私有 IPv4 检测函数
# ============================================================
is_private_ipv4() {
    local ip="$1"
    
    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    
    # 10.0.0.0/8
    if [ $i1 -eq 10 ]; then
        return 0
    fi
    
    # 172.16.0.0/12
    if [ $i1 -eq 172 ] && [ $i2 -ge 16 ] && [ $i2 -le 31 ]; then
        return 0
    fi
    
    # 192.168.0.0/16
    if [ $i1 -eq 192 ] && [ $i2 -eq 168 ]; then
        return 0
    fi
    
    # 127.0.0.0/8
    if [ $i1 -eq 127 ]; then
        return 0
    fi
    
    # 169.254.0.0/16
    if [ $i1 -eq 169 ] && [ $i2 -eq 254 ]; then
        return 0
    fi
    
    return 1
}

# ============================================================
# 私有 IPv6 检测函数
# ============================================================
is_private_ipv6() {
    local ip="$1"
    
    ip="${ip%%\%*}"
    
    local prefix="${ip:0:2}"
    local prefix4="${ip:0:4}"
    
    if [ "$ip" = "::1" ]; then
        return 0
    fi
    
    if [ "$prefix" = "fc" ] || [ "$prefix" = "fd" ]; then
        return 0
    fi
    
    if [ "$prefix4" = "fe80" ] || [ "$prefix4" = "fe9" ] || [ "$prefix4" = "fea" ] || [ "$prefix4" = "feb" ]; then
        return 0
    fi
    
    return 1
}

# ============================================================
# 测试 IP 公网可达性
# ============================================================
test_ip_public() {
    local ip="$1"
    local ip_type="$2"
    local result_file="/tmp/ip_test_$$"
    
    if [ "$ip_type" = "IPv4" ]; then
        curl -s -4 --interface "$ip" -m 5 "https://api.ipify.org" -o "$result_file" 2>/dev/null
    else
        curl -s -6 --interface "$ip" -m 5 "https://api6.ipify.org" -o "$result_file" 2>/dev/null
    fi
    
    local curl_status=$?
    local returned_ip=""
    
    if [ -f "$result_file" ]; then
        returned_ip=$(cat "$result_file")
        rm -f "$result_file"
    fi
    
    if [ $curl_status -eq 0 ] && [ -n "$returned_ip" ]; then
        if [ "$returned_ip" = "$ip" ]; then
            echo "PUBLIC"
        else
            echo "NAT"
        fi
    else
        echo "FAILED"
    fi
}

# ============================================================
# 获取本机所有 IP 地址
# ============================================================
get_all_ips() {
    local ipv4_list=()
    local ipv6_list=()
    
    if command -v ip &> /dev/null; then
        while IFS= read -r line; do
            local ip=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
            if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                ipv4_list+=("$ip")
            fi
        done < <(ip -4 addr show | grep "inet " | grep -v "127.0.0.1")
        
        while IFS= read -r line; do
            local ip=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
            ip="${ip%%\%*}"
            if [ -n "$ip" ] && [ "$ip" != "::1" ]; then
                ipv6_list+=("$ip")
            fi
        done < <(ip -6 addr show | grep "inet6 " | grep -v "::1")
    
    elif command -v ifconfig &> /dev/null; then
        while IFS= read -r line; do
            local ip=$(echo "$line" | awk '{print $2}')
            if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                ipv4_list+=("$ip")
            fi
        done < <(ifconfig | grep "inet " | grep -v "127.0.0.1")
        
        while IFS= read -r line; do
            local ip=$(echo "$line" | awk '{print $2}')
            ip="${ip%%\%*}"
            if [ -n "$ip" ] && [ "$ip" != "::1" ]; then
                ipv6_list+=("$ip")
            fi
        done < <(ifconfig | grep "inet6 " | grep -v "::1")
    fi
    
    echo "IPV4:${ipv4_list[@]}"
    echo "IPV6:${ipv6_list[@]}"
}

# ============================================================
# 公网 IP 检测函数
# ============================================================
check_public_ip() {
    echo -e "\n${BLUE}$(get_text title)${NC}"
    echo -e "${BLUE}        $(get_text ip_check_title)${NC}"
    echo -e "${BLUE}$(get_text title)${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}$(get_text error_curl)${NC}"
        echo "$(get_text install_curl)"
        exit 1
    fi
    
    echo -e "\n${YELLOW}$(get_text checking_ip)${NC}"
    local ip_data=$(get_all_ips)
    
    local ipv4_line=$(echo "$ip_data" | grep "^IPV4:")
    local ipv6_line=$(echo "$ip_data" | grep "^IPV6:")
    
    local ipv4_str="${ipv4_line#IPV4:}"
    local ipv6_str="${ipv6_line#IPV6:}"
    
    IFS=' ' read -ra IPV4_ARRAY <<< "$ipv4_str"
    IFS=' ' read -ra IPV6_ARRAY <<< "$ipv6_str"
    
    local ipv4_count=${#IPV4_ARRAY[@]}
    local ipv6_count=${#IPV6_ARRAY[@]}
    local ipv4_public=0
    local ipv4_private=0
    local ipv6_public=0
    local ipv6_private=0
    
    # 测试 IPv4
    echo -e "\n${GREEN}$(get_text title)${NC}"
    echo -e "${GREEN}  $(get_text ipv4_test) (${ipv4_count})${NC}"
    echo -e "${GREEN}$(get_text title)${NC}"
    
    if [ $ipv4_count -eq 0 ]; then
        echo -e "${RED}  $(get_text no_ipv4)${NC}"
    else
        for ip in "${IPV4_ARRAY[@]}"; do
            if [ -z "$ip" ]; then
                continue
            fi
            
            printf "  $(get_text testing) %-15s ... " "$ip"
            
            if is_private_ipv4 "$ip"; then
                echo -e "${YELLOW}$(get_text private_addr)${NC}"
                ((ipv4_private++))
                continue
            fi
            
            local result=$(test_ip_public "$ip" "IPv4")
            
            case "$result" in
                "PUBLIC")
                    echo -e "${GREEN}$(get_text public_ip_ok)${NC}"
                    ((ipv4_public++))
                    ;;
                "NAT")
                    echo -e "${YELLOW}$(get_text nat_behind)${NC}"
                    ((ipv4_private++))
                    ;;
                "FAILED")
                    echo -e "${RED}$(get_text test_failed)${NC}"
                    ((ipv4_private++))
                    ;;
            esac
        done
    fi
    
    # 测试 IPv6
    echo -e "\n${GREEN}$(get_text title)${NC}"
    echo -e "${GREEN}  $(get_text ipv6_test) (${ipv6_count})${NC}"
    echo -e "${GREEN}$(get_text title)${NC}"
    
    if [ $ipv6_count -eq 0 ]; then
        echo -e "${RED}  $(get_text no_ipv6)${NC}"
    else
        for ip in "${IPV6_ARRAY[@]}"; do
            if [ -z "$ip" ]; then
                continue
            fi
            
            printf "  $(get_text testing) %-39s ... " "$ip"
            
            if is_private_ipv6 "$ip"; then
                echo -e "${YELLOW}$(get_text private_addr)${NC}"
                ((ipv6_private++))
                continue
            fi
            
            local result=$(test_ip_public "$ip" "IPv6")
            
            case "$result" in
                "PUBLIC")
                    echo -e "${GREEN}$(get_text public_ip_ok)${NC}"
                    ((ipv6_public++))
                    ;;
                "NAT")
                    echo -e "${YELLOW}$(get_text nat_behind)${NC}"
                    ((ipv6_private++))
                    ;;
                "FAILED")
                    echo -e "${RED}$(get_text test_failed)${NC}"
                    ((ipv6_private++))
                    ;;
            esac
        done
    fi
    
    # 总结
    echo -e "\n${BLUE}$(get_text title)${NC}"
    echo -e "${BLUE}  📊 $(get_text summary)${NC}"
    echo -e "${BLUE}$(get_text title)${NC}"
    
    echo -e "\n  ${YELLOW}IPv4:${NC}"
    echo -e "    $(get_text total): ${ipv4_count}"
    if [ $ipv4_public -gt 0 ]; then
        echo -e "    ${GREEN}$(get_text public): ${ipv4_public}${NC}"
    else
        echo -e "    ${RED}$(get_text public): 0${NC}"
    fi
    echo -e "    $(get_text private): $((ipv4_count - ipv4_public))"
    
    echo -e "\n  ${YELLOW}IPv6:${NC}"
    echo -e "    $(get_text total): ${ipv6_count}"
    if [ $ipv6_public -gt 0 ]; then
        echo -e "    ${GREEN}$(get_text public): ${ipv6_public}${NC}"
    else
        echo -e "    ${RED}$(get_text public): 0${NC}"
    fi
    echo -e "    $(get_text private): $((ipv6_count - ipv6_public))"
    
    echo -e "\n${BLUE}$(get_text title)${NC}"
    if [ $ipv4_public -gt 0 ] || [ $ipv6_public -gt 0 ]; then
        echo -e "${GREEN}  $(get_text public_ip_found)${NC}"
        HAS_PUBLIC_IP=1
    else
        echo -e "${RED}  $(get_text no_public_ip)${NC}"
        HAS_PUBLIC_IP=0
    fi
    echo -e "${BLUE}$(get_text title)${NC}"
    echo ""
}

# ============================================================
# 选择语言函数
# ============================================================
select_language() {
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

# ============================================================
# 开始安装函数（占位符）
# ============================================================
start_installation() {
    echo -e "\n${GREEN}$(get_text start_install)${NC}"
    # 在这里添加实际的安装逻辑
    echo -e "${YELLOW}...${NC}"
}

# ============================================================
# 主函数
# ============================================================
main() {
    # 选择语言
    select_language
    
    # 检测公网 IP
    check_public_ip
    
    # 提示用户
    read -p "$(get_text press_enter)"
    
    # 开始安装
    start_installation
}

# 运行主函数
main "$@"
