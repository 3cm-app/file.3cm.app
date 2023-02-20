#!/bin/sh

# first time login, should by the username ubuntu
sudo su -

echo 'PermitRootLogin without-password' >>/etc/ssh/sshd_config

service sshd restart

cat /home/ubuntu/.ssh/authorized_keys >~/.ssh/authorized_keys

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

mkdir -p /data
