#!/bin/bash

# 1. 安装telnet和相关工具
yum install -y telnet-server telnet xinetd vim net-tools wget

# 2. 启用并启动telnet和xinetd服务
systemctl enable telnet.socket
systemctl enable xinetd.service
systemctl start telnet.socket
systemctl start xinetd.service

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


# 6. 下载并解压OpenSSH源码包
mkdir -p /root/soft
cd /root/soft
wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.2p1.tar.gz
tar xzvf openssh-9.2p1.tar.gz

# 7. 安装依赖和升级OpenSSL
yum install -y gcc gcc-c++ zlib-devel pam-devel openssl-devel make vim wget
yum install -y openssl098e.x86_64

# 8. 编译安装OpenSSH
cd /root/soft/openssh-9.2p1
./configure --prefix=/usr/local/openssh --sysconfdir=/etc/ssh --with-pam --with-zlib --with-md5-passwords --with-tcp-wrappers --with-selinux

# 检查配置是否成功
if [ $? -eq 0 ]; then
    make && make install
else
    echo "配置OpenSSH失败"
    exit 1
fi

# 9. 修改sshd配置文件，允许root登录
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config

# 10. 配置启动脚本并修改sshd路径
sudo cp /root/soft/openssh-9.2p1/contrib/redhat/sshd.init /etc/init.d/sshd
sed -i 's@SSHD=/usr/sbin/sshd@SSHD=/usr/local/openssh/sbin/sshd@' /etc/init.d/sshd

# 11. 替换执行命令
sudo cp -arp /usr/local/openssh/bin/* /usr/bin/

# 12. 重启sshd服务并配置自启
/etc/init.d/sshd restart
chkconfig sshd on

# 13. 查看OpenSSH版本
ssh -V

# 14. 停止xinetd和telnet服务
systemctl stop xinetd.service
systemctl stop telnet.socket

echo "操作完成，请检查并确认所有步骤是否成功。"

