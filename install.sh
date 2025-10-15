#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "arch"; then
    release="arch"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(uname -m)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release wget curl unzip tar crontabs socat ca-certificates -y >/dev/null 2>&1
        update-ca-trust force-enable >/dev/null 2>&1
    elif [[ x"${release}" == x"alpine" ]]; then
        apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"debian" ]]; then
        apt-get update -y >/dev/null 2>&1
        apt install wget curl unzip tar cron socat ca-certificates -y >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"ubuntu" ]]; then
        apt-get update -y >/dev/null 2>&1
        apt install wget curl unzip tar cron socat -y >/dev/null 2>&1
        apt-get install ca-certificates wget -y >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"arch" ]]; then
        pacman -Sy --noconfirm >/dev/null 2>&1
        pacman -S --noconfirm --needed wget curl unzip tar cron socat >/dev/null 2>&1
        pacman -S --noconfirm --needed ca-certificates wget >/dev/null 2>&1
    fi
}

check_status() {
    if [[ ! -f /usr/local/V2bX/V2bX ]]; then
        return 2
    fi
    temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_V2bX() {
    if [[ -e /usr/local/V2bX/ ]]; then
        rm -rf /usr/local/V2bX/
    fi
    mkdir /usr/local/V2bX/ -p
    cd /usr/local/V2bX/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/kkkm0/V2bX/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 V2bX 版本失败，请稍后再试${plain}"
            exit 1
        fi
        echo -e "检测到最新版本：${last_version}，开始安装"
        wget -N --progress=bar -O V2bX-linux.zip https://github.com/kkkm0/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip
    else
        last_version=$1
        wget -N --progress=bar -O V2bX-linux.zip https://github.com/kkkm0/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip
    fi

    unzip V2bX-linux.zip
    rm V2bX-linux.zip -f
    chmod +x V2bX
    mkdir -p /etc/V2bX/
    cp geoip.dat /etc/V2bX/
    cp geosite.dat /etc/V2bX/

    cat <<EOF > /etc/systemd/system/V2bX.service
[Unit]
Description=V2bX Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
WorkingDirectory=/usr/local/V2bX/
ExecStart=/usr/local/V2bX/V2bX server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable V2bX
    echo -e "${green}V2bX ${last_version}${plain} 安装完成"

    curl -o /usr/bin/V2bX -Ls https://raw.githubusercontent.com/kkkm0/V2bX-script/main/V2bX.sh
    chmod +x /usr/bin/V2bX
    ln -sf /usr/bin/V2bX /usr/bin/v2bx

    echo ""
    echo "V2bX 管理脚本使用方法:"
    echo "------------------------------------------"
    echo "V2bX              - 显示管理菜单"
    echo "V2bX start        - 启动 V2bX"
    echo "V2bX stop         - 停止 V2bX"
    echo "V2bX restart      - 重启 V2bX"
    echo "V2bX status       - 查看状态"
    echo "V2bX update       - 更新 V2bX"
    echo "V2bX uninstall    - 卸载 V2bX"
    echo "------------------------------------------"

    read -rp "是否生成默认配置文件？(y/n): " if_generate
    if [[ $if_generate == [Yy] ]]; then
        curl -o ./initconfig.sh -Ls https://raw.githubusercontent.com/kkkm0/V2bX-script/main/initconfig.sh
        source initconfig.sh
        rm -f initconfig.sh
        generate_config_file
    fi
}

echo -e "${green}开始安装${plain}"
install_base
install_V2bX $1
