#!/bin/bash

# Prevent there is no pre ssh auth
mkdir -p /root/.ssh

# Setup
sysctl -w fs.inotify.max_user_watches=525488
swapoff -a

# Essentials
apt-get install --no-install-recommends -y rsync jq

mkdir -p /data/app
mkdir -p /data/data

echo "Remember to sync deploy repo and install k3s"
