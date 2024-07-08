#!/bin/bash

# 定义颜色输出函数
red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 检查是否提供了密码参数
if [ -z "$1" ]; then
    red "请提供密码作为脚本参数，例如：./password.sh abc123"
    exit 1
fi

# 设置密码变量
password="$1"

# 定义正则表达式和对应的发行版
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

# 检查系统类型
for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int=0; int<${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "脚本暂时不支持VPS的当前系统，请使用主流操作系统" && exit 1

# 安装 wget 和 curl
if ! command -v wget &> /dev/null; then
    yellow "wget 未安装，正在安装 wget..."
    sudo ${PACKAGE_UPDATE[int]}
    sudo ${PACKAGE_INSTALL[int]} wget
fi

if ! command -v curl &> /dev/null; then
    yellow "curl 未安装，正在安装 curl..."
    sudo ${PACKAGE_UPDATE[int]}
    sudo ${PACKAGE_INSTALL[int]} curl
fi

# 获取 IPv4 和 IPv6 地址
WgcfIPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
WgcfIPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ $WgcfIPv4Status =~ "on"|"plus" ]] || [[ $WgcfIPv6Status =~ "on"|"plus" ]]; then
    wg-quick down wgcf >/dev/null 2>&1
    systemctl stop warp-go >/dev/null 2>&1
    v6=$(curl -s6m8 api64.ipify.org -k)
    v4=$(curl -s4m8 api64.ipify.org -k)
    wg-quick up wgcf >/dev/null 2>&1
    systemctl start warp-go >/dev/null 2>&1
else
    v6=$(curl -s6m8 api64.ipify.org -k)
    v4=$(curl -s4m8 api64.ipify.org -k)
fi

# 解锁 passwd 和 shadow 文件
sudo lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
sudo chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
sudo chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
sudo lsattr /etc/passwd /etc/shadow >/dev/null 2>&1

# 设置 root 密码
echo root:$password | sudo chpasswd

# 更新 SSH 配置，端口固定为22
sudo sed -i "s/^#\?Port.*/Port 22/g" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config

# 重启 SSH 服务
sudo service ssh restart >/dev/null 2>&1 # 兼容不同系统的 SSH 服务名称
sudo service sshd restart >/dev/null 2>&1

# 输出 VPS 登录信息
yellow "VPS root登录信息设置完成！"
if [[ -n $v4 && -z $v6 ]]; then
    green "VPS登录IP地址及端口为：$v4:22"
fi
if [[ -z $v4 && -n $v6 ]]; then
    green "VPS登录IP地址及端口为：$v6:22"
fi
if [[ -n $v4 && -n $v6 ]]; then
    green "VPS登录IP地址及端口为：$v4:22 或 $v6:22"
fi
green "用户名：root"
green "密码：$password"
yellow "请妥善保存好登录信息！然后重启VPS确保设置已保存！"

# 删除自身文件
rm -- "$0"

# 清除历史记录
history -c
history -w
