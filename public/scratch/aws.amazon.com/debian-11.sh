#!/bin/bash

sudo su -
cd ~

curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh
apt-get install --no-install-recommends \
	rsync

mkdir -p /data
