#!/bin/sh
SSH_PUBLIC_KEY='insert_your_ssh_public_key_here'
VERSION="4.9"
RELEASERVER=6
BASESEARCH="x86_64"
function add_ssh_public_key() {
    cd
    mkdir -p .ssh
    chmod 700 .ssh
    echo "$SSH_PUBLIC_KEY" >> .ssh/authorized_keys
    chmod 600 .ssh/authorized_keys
}

function get_network_info() {
    echo '* settings for cloud agent'
    HOSTNAME="cloudstack"
    GATEWAY="10.0.0.1"
    IPADRR="10.0.0.211"
    NETMASK="255.255.255.0"
    DOMAIN="apalia.local"
    DNS1="10.0.0.254"
}

function get_nfs_info() {
    echo '* settings for nfs server'
    NFS_SERVER_PRIMARY=/export/primary
    NFS_SERVER_SECONDARY=/export/secondary
    NFS_SERVER_IP="$IPADRR"
}

function get_nfs_network() {
    echo '* settings for nfs server'
    NETWORK="0.0.0.0/0"
}

function install_common() {
     yum update -y
     sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
     setenforce permissive
     echo "[cloudstack]
name=cloudstack
baseurl=http://packages.shapeblue.com/cloudstack/upstream/centos/$VERSION
enabled=1
gpgcheck=0" > /etc/yum.repos.d/CloudStack.repo
     if [ $VERSION == "4.9" ]; then
	     echo "[mysql-connectors-community]
name=MySQL Community connectors
baseurl=http://repo.mysql.com/yum/mysql-connectors-community/el/$RELEASERVER/$BASESEARCH/
enabled=1
gpgcheck=1" > /etc/yum.repos.d/mysql.repo
	rpm --import http://repo.mysql.com/RPM-GPG-KEY-mysql
	yum install mysql-connector-python -y
	fi
     yum install ntp wget -y
     service ntpd start
     chkconfig ntpd on
}

function install_management() {
     yum install cloudstack-management mysql-server expect -y

     head -7 /etc/my.cnf > /tmp/before
     tail -n +7 /etc/my.cnf > /tmp/after
     cat /tmp/before > /etc/my.cnf
     echo "innodb_rollback_on_timeout=1
innodb_lock_wait_timeout=600
max_connections=350
log-bin=mysql-bin
binlog-format = 'ROW'" >> /etc/my.cnf
     cat /tmp/after >> /etc/my.cnf
     rm -rf /tmp/before /tmp/after

     service mysqld start
     chkconfig mysqld on

     expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none): \"
send \"\n\"
expect \"Set root password?\"
send \"Y\n\"
expect \"New password: \"
send \"password\n\"
expect \"Re-enter new password: \"
send \"password\n\"
expect \"Remove anonymous users?\"
send \"Y\n\"
expect \"Disallow root login remotely?\"
send \"Y\n\"
expect \"Remove test database and access to it?\"
send \"Y\n\"
expect \"Reload privilege tables now?\"
send \"Y\n\"
interact
"
     cloudstack-setup-databases cloud:password@localhost --deploy-as=root:password
     echo "Defaults:cloud !requiretty" >> /etc/ers
     cloudstack-setup-management
     chkconfig cloudstack-management on
     chown cloud:cloud /var/log/cloudstack/management/catalina.out
}

function initialize_storage() {
     service rpcbind start
     chkconfig rpcbind on
     service nfs start
     chkconfig nfs on
     mkdir -p /mnt/primary
     mkdir -p /mnt/secondary
     mount -t nfs ${NFS_SERVER_IP}:${NFS_SERVER_PRIMARY} /mnt/primary
    sleep 10
     mount -t nfs ${NFS_SERVER_IP}:${NFS_SERVER_SECONDARY} /mnt/secondary
    sleep 10
     rm -rf /mnt/primary/*
     rm -rf /mnt/secondary/*
     /usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt -m /mnt/secondary -u http://cloudstack.apt-get.eu/systemvm/4.6/systemvm64template-4.6.0-vmware.ova -h vmware -F
    sync
     umount /mnt/primary
     umount /mnt/secondary
     rmdir /mnt/primary
     rmdir /mnt/secondary
}

function set_ip() {
    HWADDR=`grep HWADDR /etc/sysconfig/network-scripts/ifcfg-eth0 | awk -F '"' '{print $2}'`
     echo "DEVICE=eth0
HWADDR=$HWADDR
NM_CONTROLLED=no
ONBOOT=yes
HOSTNAME=$HOSTNAME
IPADDR=$IPADRR
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS1=$DNS1" > /etc/sysconfig/network-scripts/ifcfg-eth0
 hostname $HOSTNAME
 echo "$IPADRR	$HOSTNAME	$HOSTNAME.$DOMAIN" >> /etc/hosts
 echo "search $DOMAIN
nameserver $DNS1" > /etc/resolv.conf
 service network restart
}
function set_acl(){
	if [ $RELEASERVER -lt 7 ]; then
		service iptables stop
		chkconfig iptables off
	else
		 systemctl stop firewalld 
		 systemctl disable firewalld
	fi
}
function install_nfs() {
     yum install nfs-utils -y
     service rpcbind start
     chkconfig rpcbind on
     service nfs start
     chkconfig nfs on
     mkdir -p $NFS_SERVER_PRIMARY
     mkdir -p $NFS_SERVER_SECONDARY
     echo "$NFS_SERVER_PRIMARY   *(rw,async,no_root_squash)" >  /etc/exports
     echo "$NFS_SERVER_SECONDARY *(rw,async,no_root_squash)" >> /etc/exports
     exportfs -a
     echo "LOCKD_TCPPORT=32803
LOCKD_UDPPORT=32769
MOUNTD_PORT=892
RQUOTAD_PORT=875
STATD_PORT=662
STATD_OUTGOING_PORT=2020" >> /etc/sysconfig/nfs
}
    get_network_info
    get_nfs_network
    get_nfs_info
    add_ssh_public_key
    set_ip
    set_acl
    install_common
    install_nfs
    install_management
    initialize_storage
    sync
    sync
    sync
    reboot
