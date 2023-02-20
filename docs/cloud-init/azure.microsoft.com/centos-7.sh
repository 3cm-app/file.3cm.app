#!/bin/bash

yum update -y

yum install -y tmux
yum install -y yum-utils

# install docker
# https://docs.docker.com/engine/installation/linux/centos/
tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF


tee /etc/resolv.conf <<EOF
nameserver 8.8.8.8
EOF

# install docker engine
yum install -y docker-engine

# docker engine init at boot
chkconfig docker on

# install docker compose
curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# tools
yum install -y git
yum install -y unzip
yum install -y dstat
yum install -y nc
yum install -y ntpdate
