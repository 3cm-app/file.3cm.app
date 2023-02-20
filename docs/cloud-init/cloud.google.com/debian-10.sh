#!/bin/bash

# ssh login by the user: username of the ssh key of metadata on gcp console

# copy credantial for root
sudo mkdir -p /root/.ssh
sudo cp ~/.ssh/authorized_keys /root/.ssh/

sudo su -

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

apt install rsync

mkdir -p /data

# Remember edit local the `User` of ~/.ssh/config
