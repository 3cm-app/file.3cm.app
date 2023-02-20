#!/bin/bash

# TODO
echo "This shell doesn't work."
exit 2

apt-get update

apt-get install -y apt-transport-https ca-certificates

echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' > /etc/apt/sources.list.d/docker.list

apt-get install -y docker-engine
apt-get install -y tmux

# http://lukeberndt.com/2016/getting-docker-up-on-linode-with-ubuntu-16-04/

apt-get install -y linux-image-virtual grub2

curl -sSL https://get.docker.com/ | sh

# sudo usermod -aG docker your-user

# install ab benchmark tool
apt-get install -y apache2-utils
