#!/bin/bash

# 1. 安装telnet和相关工具
yum install -y telnet-server telnet xinetd vim net-tools wget

# 2. 关闭防火墙
systemctl enable telnet.socket
systemctl enable xinetd.service
systemctl start telnet.socket
systemctl start xinetd.service
systemctl stop firewalld
echo "已关闭防火墙"

# 3. 检查服务状态
systemctl status xinetd.service
systemctl status telnet.socket

# 4. 编辑/etc/xinetd.d/telnet文件，禁用telnet服务
cat <<EOL > /etc/xinetd.d/telnet
# default: on
# description: The telnet server serves telnet sessions; it uses \
#      unencrypted username/password pairs for authentication.
service telnet
{
       flags          = REUSE
       socket_type    = stream
       wait          = no
       user          = root
       server         = /usr/sbin/in.telnetd
       log_on_failure  += USERID
       disable        = no
}
EOL

# 5. 编辑/etc/securetty文件，添加pts终端
cat <<EOL >> /etc/securetty
pts/1
pts/2
pts/3
pts/4
EOL

# 提示用户退出ssh，使用telnet登录到服务器
echo "退出ssh，使用telnet登录到服务器"

systemctl start telnet.socket

# 6. 全盘查找是否存在OpenSSH源码包
echo "正在全盘查找 openssh-9.2p1.tar.gz 源码包..."
SEARCH_PATH=$(find / -name "openssh-9.2p1.tar.gz" 2>/dev/null | head -n 1)

if [ -z "$SEARCH_PATH" ]; then
    echo "未找到现有的 OpenSSH 源码包，开始下载..."
    mkdir -p /root/soft
    cd /root/soft
    wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.2p1.tar.gz
    SEARCH_PATH="/root/soft/openssh-9.2p1.tar.gz"
else
    echo "找到现有的 OpenSSH 源码包：$SEARCH_PATH"
    cd $(dirname "$SEARCH_PATH")
fi

# 7. 解压源码包
tar xzvf "$SEARCH_PATH"

# 8. 安装依赖和升级OpenSSL
yum install -y gcc gcc-c++ zlib-devel pam-devel openssl-devel make vim wget
yum install -y openssl098e.x86_64

# 9. 编译安装OpenSSH
cd openssh-9.2p1
./configure --prefix=/usr/local/openssh --sysconfdir=/etc/ssh --with-pam --with-zlib --with-md5-passwords --with-tcp-wrappers --with-selinux

# 检查配置是否成功
if [ $? -eq 0 ]; then
    make && make install
else
    echo "配置OpenSSH失败"
    exit 1
fi

# 10. 修改sshd配置文件，允许root登录
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config

# 11. 配置启动脚本并修改sshd路径
sudo cp contrib/redhat/sshd.init /etc/init.d/sshd
sed -i 's@SSHD=/usr/sbin/sshd@SSHD=/usr/local/openssh/sbin/sshd@' /etc/init.d/sshd

# 12. 替换执行命令
sudo cp -arp /usr/local/openssh/bin/* /usr/bin/

# 13. 重启sshd服务并配置自启
/etc/init.d/sshd restart
chkconfig sshd on

# 14. 查看OpenSSH版本
ssh -V

# 15. 停止xinetd和telnet服务
echo "确认ssh升级成功后，手动停止telnet服务"
echo "systemctl stop xinetd.service"
echo "systemctl stop telnet.socket"
