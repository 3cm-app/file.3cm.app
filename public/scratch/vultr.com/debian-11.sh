#!/bin/bash

curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh

wget --no-check-certificate -O https://github.com/teddysun/across/raw/master/bbr.sh
chmod +x ./bbr.sh
./bbr.sh

ufw disable

mkdir /data
apt install rsync -y
