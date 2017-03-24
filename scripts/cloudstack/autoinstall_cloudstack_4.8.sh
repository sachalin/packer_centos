#!/bin/sh
set -e
set -x
sudo su 
SSH_PUBLIC_KEY='insert_your_ssh_public_key_here'
VERSION="4.8"
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
    GATEWAY="172.16.107.2"
    IPADRR="172.16.107.128"
    NETMASK="255.255.255.0"
    DOMAIN="localdomain"
    DNS1="172.16.107.2"
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
    sudo yum update -y
    sudo sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    sudo setenforce permissive
    sudo echo "[cloudstack]
name=cloudstack
baseurl=http://packages.shapeblue.com/cloudstack/upstream/centos/$VERSION
enabled=1
gpgcheck=0" > /etc/yum.repos.d/CloudStack.repo
    sudo yum install ntp wget -y
    sudo service ntpd start
    sudo chkconfig ntpd on
}

function install_management() {
    sudo yum install cloudstack-management mysql-server expect -y

    sudo head -7 /etc/my.cnf > /tmp/before
    sudo tail -n +7 /etc/my.cnf > /tmp/after
    sudo cat /tmp/before > /etc/my.cnf
    sudo echo "innodb_rollback_on_timeout=1
innodb_lock_wait_timeout=600
max_connections=350
log-bin=mysql-bin
binlog-format = 'ROW'" >> /etc/my.cnf
    sudo cat /tmp/after >> /etc/my.cnf
    sudo rm -rf /tmp/before /tmp/after

    sudo service mysqld start
    sudo chkconfig mysqld on

    sudo expect -c "
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
    sudo cloudstack-setup-databases cloud:password@localhost --deploy-as=root:password
    sudo echo "Defaults:cloud !requiretty" >> /etc/sudoers
    sudo cloudstack-setup-management
    sudo chkconfig cloudstack-management on
    sudo chown cloud:cloud /var/log/cloudstack/management/catalina.out
}

function initialize_storage() {
    sudo service rpcbind start
    sudo chkconfig rpcbind on
    sudo service nfs start
    sudo chkconfig nfs on
    sudo mkdir -p /mnt/primary
    sudo mkdir -p /mnt/secondary
    sudo mount -t nfs ${NFS_SERVER_IP}:${NFS_SERVER_PRIMARY} /mnt/primary
    sleep 10
    sudo mount -t nfs ${NFS_SERVER_IP}:${NFS_SERVER_SECONDARY} /mnt/secondary
    sleep 10
    sudo rm -rf /mnt/primary/*
    sudo rm -rf /mnt/secondary/*
    sudo /usr/share/cloudstack-common/scripts/storage/secondary/cloud-install-sys-tmplt -m /mnt/secondary -u http://cloudstack.apt-get.eu/systemvm/4.6/systemvm64template-4.6.0-vmware.ova -h vmware -F
    sync
    sudo umount /mnt/primary
    sudo umount /mnt/secondary
    sudo rmdir /mnt/primary
    sudo rmdir /mnt/secondary
}

function set_ip() {
    HWADDR=`grep HWADDR /etc/sysconfig/network-scripts/ifcfg-eth0 | awk -F '"' '{print $2}'`
    sudo echo "DEVICE=eth0
HWADDR=$HWADDR
NM_CONTROLLED=no
ONBOOT=yes
HOSTNAME=$HOSTNAME
IPADDR=$IPADRR
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS1=$DNS1" > /etc/sysconfig/network-scripts/ifcfg-eth0
sudo hostname $HOSTNAME
sudo echo "$IPADRR	$HOSTNAME	$HOSTNAME.$DOMAIN" >> /etc/hosts
sudo echo "search $DOMAIN
nameserver $DNS1" > /etc/resolv.conf
sudo service iptables stop
sudo chkconfig iptables off
sudo service network restart
}

function install_nfs() {
    sudo yum install nfs-utils -y
    sudo service rpcbind start
    sudo chkconfig rpcbind on
    sudo service nfs start
    sudo chkconfig nfs on
    sudo mkdir -p $NFS_SERVER_PRIMARY
    sudo mkdir -p $NFS_SERVER_SECONDARY
    sudo echo "$NFS_SERVER_PRIMARY   *(rw,async,no_root_squash)" >  /etc/exports
    sudo echo "$NFS_SERVER_SECONDARY *(rw,async,no_root_squash)" >> /etc/exports
    sudo exportfs -a
    sudo echo "LOCKD_TCPPORT=32803
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
    install_common
    install_nfs
    install_management
    initialize_storage
    sync
    sync
    sync
    reboot
