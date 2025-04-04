#!/bin/bash

apt-get update

apt-get install -y tmux
apt-get install -y curl

# install docker
curl -sSL https://get.docker.com/ | sh

# install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.7.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# install docker bash-completion
curl -L https://raw.githubusercontent.com/docker/compose/$(docker-compose version --short)/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose

# sudo usermod -aG docker your-user

# install ab benchmark tool
apt-get install -y apache2-utils
