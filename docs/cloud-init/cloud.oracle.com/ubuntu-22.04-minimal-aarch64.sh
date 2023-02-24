#!/bin/sh

# first time login, should by the username ubuntu
sudo su -

echo 'PermitRootLogin without-password' >>/etc/ssh/sshd_config

service sshd restart

mkdir -p ~/.ssh
cat /home/ubuntu/.ssh/authorized_keys >~/.ssh/authorized_keys

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

mkdir -p /data

apt-get install --no-install-recommends \
	rsync

# default security group only open others ports than 80, so we have to do this manually first
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
