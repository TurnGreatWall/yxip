#!/bin/bash
export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "${RED}${1}${PLAIN}"
}

green() {
    echo -e "${GREEN}${1}${PLAIN}"
}

yellow() {
    echo -e "${YELLOW}${1}${PLAIN}"
}

# 选择客户端 CPU 架构
archAffix(){
    case "$(uname -m)" in
        i386 | i686 ) echo '386' ;;
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

endpointyx(){    
    # 删除之前的优选结果文件，以避免出错
    rm -f result.csv

    # 下载优选工具软件，感谢 GitHub 项目：https://github.com/peanut996/CloudflareWarpSpeedTest
    wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-$(archAffix) -O warp

    # 检查是否下载成功
    if [ $? -ne 0 ]; then
        yellow "下载优选工具失败，正在尝试重新下载..."
        # 关闭接口
        wg-quick down wgcf
        # 再次尝试下载优选工具
        wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-$(archAffix) -O warp || { red "再次下载优选工具失败，退出脚本"; exit 1; }
    fi
    
    # 取消 Linux 自带的线程限制，以便生成优选 Endpoint IP
    ulimit -n 102400
    
    # 启动 WARP Endpoint IP 优选工具
    chmod +x warp
    ./warp -ipv6
    
    # 获取优选结果中的第一个值（排除标题行）
    best_endpoint=$(tail -n +2 result.csv | awk -F, '$3!="timeout ms" {print $1; exit}')
    
    # 提取端口
    best_port=$(echo "$best_endpoint" | awk -F: '{print $2}')
    
    # 修改文件 /etc/wireguard/wgcf.conf
    sed -i "s/Endpoint = .*/Endpoint = $best_endpoint/; s/#Port = 2408/Port = $best_port/" /etc/wireguard/wgcf.conf
    
    # 显示修改后的配置信息
    green "已将优选的 Endpoint IP 写入 /etc/wireguard/wgcf.conf 文件："
    echo "Endpoint = $best_endpoint"
    
    # 启动接口
    wg-quick up wgcf
    
    # 删除 WARP Endpoint IP 优选工具及其附属文件
    rm -f warp
}

endpointyx
