#!/bin/bash

# ssh-copy-id -i ~/.ssh/id_rsa.pub pi@raspberrypi.local
# ssh pi@raspberrypi.local
# sudo mkdir /root/.ssh
# sudo mv ~/.ssh/authorized_keys /root/.ssh/
# sudo chown root:root /root/.ssh/authorized_keys
# sudo nano /etc/ssh/sshd_config
# 	PasswordAuthentication no
# 	PermitRootLogin prohibit-password
# 	Match address 192.168.*.*
# 		PasswordAuthentication yes
# sudo service sshd restart

mkdir -p /data

# setup
sysctl -w fs.inotify.max_user_watches=525488

# essentials
apt-get install --no-install-recommends -y \
	git \
	rsync \
	jq

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh

# install docker-compose (no official pre-built for armv6l, so we only can compile it...)
