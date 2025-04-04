#!/bin/bash

# Prevent there is no pre ssh auth
mkdir -p /root/.ssh

# Setup
sysctl -w fs.inotify.max_user_watches=525488
swapoff -a

# Essentials
apt-get install --no-install-recommends -y git rsync jq

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# install docker-compose
DOCKER_COMPOSE_VERSION=$(git ls-remote --tags git://github.com/docker/compose.git | awk '{print $2}' | grep -v "docs\|rc" | awk -F'/' '{print $3}' | sort -V | tail -n1)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# mount point
mkdir -p /data/app

# https://linuxize.com/post/install-configure-fail2ban-on-debian-10/
apt-get install --no-install-recommends -y fail2ban
cat >/etc/fail2ban/jail.local <<EOF
[sshd]
enabled   = true
maxretry  = 3
findtime  = 1w
bantime   = 1d
EOF
systemctl restart fail2ban
