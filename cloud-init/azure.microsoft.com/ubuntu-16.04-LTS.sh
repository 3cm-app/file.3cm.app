#!/bin/bash

#
# mount disk
# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-classic-attach-disk/
#

# check scsi
grep SCSI /var/log/syslog

# double check the disk id
lsblk
# fdisk -l

fdisk /dev/sdc
#n
#p
#(enter)1
#(enter)2048
#(enter)2145386495
#w

# confirm the disk id
lsblk

# format the empty disk
mkfs -t ext4 /dev/sdc1

# mount the disk
mkdir /data
mount /dev/sdc1 /data

# check disk mounted
blkid

# auto mount disk on boot
echo '/dev/sdc1 /data ext4 defaults 0 0' >> /etc/fstab

# check reboot setting
cat /etc/fstab

#
# install docker
#

curl -sSL https://get.docker.com/ | sh

# sudo usermod -aG docker your-user

# Docker to start on boot
systemctl enable docker

# install docker compose
curl -L https://github.com/docker/compose/releases/download/1.8.0/run.sh > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
