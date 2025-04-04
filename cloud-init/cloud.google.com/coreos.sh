#!/bin/sh

sudo mkdir /data
sudo chmod 777 /data

sudo /usr/sbin/sysctl -w vm.swappiness=0
