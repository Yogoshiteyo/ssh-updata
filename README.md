# openssh升级记录
## 基本情况：客户漏洞扫描发现数据库服务器和web服务器存在openssh相关漏洞，经排查现有ssh版本为5.X，操作系统为centos6.X，最新ssh版本为9.X(备份之前的ssh：mv /etc/ssh{,.bak})
```bash
curl -O https://raw.githubusercontent.com/Yogoshiteyo/ssh-updata/main/upssh.sh && chmod +x upssh.sh && ./upssh.sh
```
## 1.替换软件源，将软件源替换为aliyun源
```bash
minorver=6.10
sudo sed -e "s|^mirrorlist=|#mirrorlist=|g" \
         -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=https://mirrors.aliyun.com/centos-vault/$minorver|g" \
         -i.bak \
         /etc/yum.repos.d/CentOS-*.repo
wget -O /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-archive-6.repo
yum clean all
yum makecache
```
## 2.安装telnet，防止升级ssh的过程中失去连接
```bash
yum install telnet-server telnet xinetd vim net-tools wget
```
~centos7.9~
```bash
systemctl enable xinetd.service
systemctl enable telnet.socket
systemctl start telnet.socket
systemctl start xinetd.service
systemctl status xinetd.service
systemctl status telnet.socket
```

编辑/etc/xinetd.d/telnet文件，将disable 改为no
```bash
vim /etc/xinetd.d/telnet
```
    
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
编辑/etc/securetty,再末尾加上pts/1,pts/2......
```bash
vim /etc/securetty
```
    console
    vc/1
    vc/2
    vc/3
    vc/4
    vc/5
    vc/6
    vc/7
    vc/8
    vc/9
    vc/10
    vc/11
    tty1
    tty2
    tty3
    tty4
    tty5
    tty6
    tty7
    tty8
    tty9
    tty10
    tty11
    pts/1
    pts/2
    pts/3
    pts/4
    ~              
退出ssh，使用telnet登录到服务器    

## 3.下载ssh源码包，安装依赖
1). 下载openssh源码包,并解压
```bash
mkdir -p /root/soft
cd /root/soft
wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.2p1.tar.gz
tar xzvf openssh-9.2p1.tar.gz
```
2).安装依赖,升级openssl
```bash
yum install gcc gcc-c++ zlib-devel pam-devel openssl-devel make vim wget -y
yum install -y openssl098e.x86_64
```

3).编译安装openssh
```bash
cd /root/soft/openssh-9.2p1
./configure --prefix=/usr/local/openssh --sysconfdir=/etc/ssh --with-pam --with-zlib --with-md5-passwords --with-tcp-wrappers --with-selinux
echo $? #判断一下是否成功，如果返回零则继续
make && make install
```
## 4.进行安装后的配置
1). 修改sshd配置文件,将PermitRootLogin前的#去掉，并改为PermitRootLogin yes。
```bash
vim /etc/ssh/sshd_config
```
    #Port 22
    #AddressFamily any
    #ListenAddress 0.0.0.0
    #ListenAddress ::
    
    #HostKey /etc/ssh/ssh_host_rsa_key
    #HostKey /etc/ssh/ssh_host_ecdsa_key
    #HostKey /etc/ssh/ssh_host_ed25519_key
    
    # Ciphers and keying
    #RekeyLimit default none
    
    # Logging
    #SyslogFacility AUTH
    #LogLevel INFO
    
    # Authentication:
    
    #LoginGraceTime 2m
    PermitRootLogin yes
    #StrictModes yes
    #MaxAuthTries 6
    #MaxSessions 10
2).配置启动脚本,修改sshd路径为/usr/local/openssh/sbin/sshd。
```bash
sudo cp /root/soft/openssh-9.2p1/contrib/redhat/sshd.init /etc/init.d/sshd
vim /etc/init.d/sshd
```
    # source function library
    . /etc/rc.d/init.d/functions
    
    # pull in sysconfig settings
    [ -f /etc/sysconfig/sshd ] && . /etc/sysconfig/sshd
    
    RETVAL=0
    prog="sshd"
    
    # Some functions to make the below more readable
    SSHD=/usr/local/openssh/sbin/sshd
    PID_FILE=/var/run/sshd.pid
    
3).替换执行命令
```bash
sudo cp -arp /usr/local/openssh/bin/* /usr/bin/
```
4).重启服务并配置自启,查看版本号
```bash
/etc/init.d/sshd restart
chkconfig sshd on
ssh -V
```
    [root@localhost ~]# ssh -V
    OpenSSH_9.2p1, OpenSSL 1.0.1e-fips 11 Feb 2013
```bash
    systemctl stop xinetd.service
    systemctl stop telnet.socket
```
