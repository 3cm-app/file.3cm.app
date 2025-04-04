#!/bin/bash

sudo su -
cd ~

sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
service restart sshd

mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
mkdir -p /data
mount -o discard,defaults /dev/sdb /data
echo "UUID=$(blkid -s UUID -o value /dev/sdb) /data ext4 discard,defaults,nofail 0 2" >>/etc/fstab

curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh
