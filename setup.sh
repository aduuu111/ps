#!/bin/bash

# 检查是否提供了密码
if [ -z "$1" ]; then
    echo "请提供 root 用户密码作为参数运行脚本"
    exit 1
fi

ROOT_PASSWORD=$1

# 定义不同系统的包管理命令
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

# 检测操作系统和版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

# 清空 root 用户的 authorized_keys 文件
sudo bash -c 'cat /dev/null > /root/.ssh/authorized_keys'

# 设置 root 用户的密码
echo "root:$ROOT_PASSWORD" | sudo chpasswd

# 配置 SSH 允许 root 登录和密码认证
configure_ssh() {
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
    # 禁用包含其他配置文件的功能（如果需要）
    sudo sed -i 's/^#\?Include.*/#Include/g' /etc/ssh/sshd_config
}

# 检测系统并安装必要的插件
for i in "${!REGEX[@]}"; do
    if echo "${CMD[@]}" | grep -iqE "${REGEX[$i]}"; then
        SYSTEM=${RELEASE[$i]}
        UPDATE_CMD=${PACKAGE_UPDATE[$i]}
        INSTALL_CMD=${PACKAGE_INSTALL[$i]}
        echo "检测到 $SYSTEM 系统"
        echo "更新系统包..."
        sudo $UPDATE_CMD
        echo "安装必要的插件..."
        sudo $INSTALL_CMD curl wget vim
        break
    fi
done

# 针对不同操作系统的特定配置
case "$OS" in
    ubuntu)
        echo "配置 SSH 设置..."
        configure_ssh
        sudo systemctl restart sshd
        ;;
    debian)
        echo "配置 SSH 设置..."
        configure_ssh
        sudo systemctl restart ssh
        ;;
    centos)
        echo "配置 SSH 设置..."
        sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
        sudo systemctl restart sshd
        ;;
    almalinux)
        echo "配置 SSH 设置..."
        sudo sed -i 's/^#\?PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
        sudo systemctl restart sshd
        ;;
    amzn)
        echo "配置 SSH 设置..."
        configure_ssh
        sudo systemctl restart sshd
        ;;
    opensuse*)
        echo "配置 SSH 设置..."
        configure_ssh
        sudo systemctl restart sshd
        ;;
    freebsd)
        echo "配置 SSH 设置..."
        sudo sysrc sshd_enable=YES
        sudo sed -i '' 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#\?Include.*/#Include/g' /etc/ssh/sshd_config
        if grep -q '^ssh' /etc/inetd.conf; then
            sudo sed -i '' 's/^ssh/#ssh/g' /etc/inetd.conf
            sudo service inetd restart
        fi
        sudo service sshd restart
        ;;
    *)
        echo "配置 SSH 设置..."
        configure_ssh
        sudo systemctl restart sshd || sudo systemctl restart ssh || sudo service sshd restart || sudo service ssh restart
        ;;
esac

echo "SSH 配置已更新。现在可以使用 root 用户和指定的密码登录。"

# 删除脚本自身
rm -- "$0"
