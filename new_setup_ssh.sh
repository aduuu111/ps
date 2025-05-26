#!/bin/bash

# 检查是否提供了密码
if [ -z "$1" ]; then
    echo "请提供 root 用户密码作为参数运行脚本，例如："
    echo "curl -O 47.129.30.4/setup_ssh.sh && chmod +x setup_ssh.sh && ./setup_ssh.sh YourPasswordHere"
    exit 1
fi

ROOT_PASSWORD=$1

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
    # 修复 sshd_config 文件权限
    sudo chmod 600 /etc/ssh/sshd_config
}

# 针对不同操作系统的特定配置
case "$OS" in
    ubuntu)
        echo "检测到 Ubuntu"
        configure_ssh
        sudo systemctl restart sshd
        ;;

    debian)
        echo "检测到 Debian"
        configure_ssh
        # 对于 Debian 11 系统，确保正确重启 SSH 服务
        sudo systemctl restart ssh || sudo service ssh restart
        ;;

    centos)
        echo "检测到 CentOS"
        sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
        sudo systemctl restart sshd
        ;;

    almalinux)
        echo "检测到 AlmaLinux"
        sudo sed -i 's/^#\?PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config
        sudo systemctl restart sshd
        ;;

    amzn)
        echo "检测到 Amazon Linux"
        configure_ssh
        sudo systemctl restart sshd
        ;;

    opensuse*)
        echo "检测到 openSUSE"
        configure_ssh
        sudo systemctl restart sshd
        ;;

    freebsd)
        echo "检测到 FreeBSD"
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
        echo "检测到不支持的操作系统: $OS，默认执行"
        configure_ssh
        sudo systemctl restart sshd || sudo systemctl restart ssh || sudo service sshd restart || sudo service ssh restart
        ;;

esac

echo "SSH 配置已更新。现在可以使用 root 用户和指定的密码登录。"

# 删除脚本自身
rm -- "$0"
