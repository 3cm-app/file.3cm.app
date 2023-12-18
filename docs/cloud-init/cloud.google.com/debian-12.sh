#!/bin/bash

sudo su -
cd ~

sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
service restart sshd

curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh

mkdir -p /data

apt update
apt upgrade -y
apt install --no-install-recommends -y \
	rsync \
	jq
