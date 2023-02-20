#!/bin/bash -e

__DIR__=$(dirname "${BASH_SOURCE[0]}")

cd ~

#########
# xcode #
#########

# Before install xcode command line tools, probably need to install XCode.app itself...
xcode-select --install
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch

####################
# package manarger #
####################

# homebrew:
# https://github.com/Homebrew/brew/blob/master/docs/Installation.md
# https://brew.sh/
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

###################
# vpn, proxy, GFW #
###################

# Basic auto reconnect ssh tunnel
brew install autossh

# For socks5, http proxy
# brew install polipo # socks5 -> http
# brew install --cask shadowsocksx-ng
# brew install --cask shadowsocksx-ng-r
# brew install --cask v2rayx
brew install --cask v2rayu

# Prevent dns poisoning
brew install dnscrypt-proxy
sudo brew services start dnscrypt-proxy

DNS_LIST=(
	127.0.0.1      # local via dnscrypt-proxy
	8.8.8.8        # google
	8.8.4.4        # google
	208.67.222.222 # opendns
	208.67.220.220 # opendns
	9.9.9.9        # ibm
	180.76.76.76   # baidu
)
networksetup -setdnsservers Wi-Fi "${DNS_LIST[@]}"
# Or manually setup DNS: System Preferences -> Networks -> WiFi -> Advanced -> DNS

##########
# remote #
##########

brew install ssh-copy-id
brew install openssl

###########
# network #
###########

brew install mtr # cmd: traceroute, ping
brew install tcping
brew install --cask wireshark
# brew install --cask ngrok
brew install websocat

###########################
# vm, container, emulator #
###########################

brew install --cask docker
# brew install ctop
# brew install --cask vmware-fusion
# brew install --cask bluestacks

################
# sync, backup #
################

brew install rclone

brew install --cask dropbox
# https://github.com/caskroom/homebrew-cask/issues/37271#issuecomment-319275948
brew install --cask google-backup-and-sync

brew install mackup # Backup configurations in Home

##################
# dev essentials #
##################

# unix command, gun tools
brew install coreutils
echo 'PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"' >>~/.bash_profile
echo 'MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"' >>~/.bash_profile

# git
brew install git
git config --global credential.helper osxkeychain
brew install git-lfs
git lfs install
git lfs install --system
brew install git-extras
brew install git-delta
# brew install --cask sourcetree # Using vscode extension - "Git Graph" instead
brew install hub # github cli

brew install wget
brew install curl
echo 'PATH="/usr/local/opt/curl/bin:$PATH"' >>~/.bash_profile

# brew install tmux

###############
# lang (bash) #
###############

# latest bash
brew install bash
echo $(brew --prefix)/bin/bash | sudo tee -a /etc/shells
chsh -s $(brew --prefix)/bin/bash

# using builtin bash(< v4)
# brew install bash-completion
# using newer bash(>= v4)
brew install bash-completion@2
echo '[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"' >>~/.bash_profile
# Don't set alias with _ as prefix, because bash-completion@2 files using _ as function prefix...

#####################
# lang (node, deno) #
#####################

brew install deno
brew install node
[[ ! -r "/usr/local/etc/bash_completion.d/node" ]] && node --completion-bash >/usr/local/etc/bash_completion.d/node
brew install yarn

# npm -g list --depth 0
npm i -g eslint \
	eslint-config-standard \
	eslint-plugin-import \
	eslint-plugin-node \
	eslint-plugin-promise \
	eslint-plugin-standard

npm i -g commitizen
npm i -g cz-conventional-changelog
# npm i -g cz-emoji

npm i -g qrcode

# npm i -g hexo-cli
brew install gatsby-cli
npm i -g docsify-cli
npm i -g hackmyresume
# npm i -g wepy-cli
deno run -A https://deno.land/x/aleph/install.ts

##############################
# lang (c, c++, objective-c) #
##############################

# brew install autoconf automake libtool
brew install ninja

###############
# lang (rust) #
###############

# brew install rust
brew install rustup-init
rustup-init
rustup component add rustfmt-preview --toolchain stable-x86_64-apple-darwin

brew install cmake
brew install rust-analyzer

##############
# lang (php) #
##############

# New MacOS is on php7.1, so there is no need to install 7

# brew tap homebrew/homebrew-php
# brew install php72 --with-pear # to override default mac php5.5 (too old and apple recommand do not delete it?!)... php autoformat need at least 7, so...
# brew install composer # using docker instead

#################
# lang (others) #
#################

brew install python # v3

brew install ruby # override default old version, some apps need this
gem update --system

brew install lua

brew install go
echo 'PATH=$PATH:/usr/local/opt/go/libexec/bin' >>~/.bash_profile

brew install adoptopenjdk # requirement for dbeaver-community

#################
# lang (mobile) #
#################

brew install flutter

# android
brew install --cask android-ndk
brew install apktool
brew install --cask androidtool

# ios
brew install cocoapods

# test
# brew install --cask appium
npm install -g appium --unsafe-perm=true --allow-root

#####################
# IDE, editor, note #
#####################

# brew install --cask black-screen # this sucks
brew install nano

# brew install --cask visual-studio-code

brew install --cask vscodium
# vscodium --list-extensions
vscodium --install-extension \
	0x9ef.vscode-vlang \
	42Crunch.vscode-openapi \
	AlanWalk.markdown-toc \
	ask-toolkit.alexa-skills-kit-toolkit \
	bmewburn.vscode-intelephense-client \
	bungcip.better-toml \
	DavidAnson.vscode-markdownlint \
	DavidWang.ini-for-vscode \
	dbaeumer.vscode-eslint \
	eamodio.gitlens \
	EditorConfig.EditorConfig \
	eriklynd.json-tools \
	formulahendry.auto-close-tag \
	formulahendry.auto-rename-tag \
	foxundermoon.shell-format \
	golang.go \
	HookyQR.JSDocTagComplete \
	jeff-hykin.code-eol \
	kevinkyang.auto-comment-blocks \
	kumar-harsh.graphql-for-vscode \
	laktak.hjson \
	matklad.rust-analyzer \
	mrmlnc.vscode-json5 \
	mrmlnc.vscode-less \
	ms-azuretools.vscode-docker \
	ms-vscode-remote.remote-containers \
	ms-vscode-remote.remote-ssh \
	ms-vscode-remote.remote-ssh-edit \
	ms-vscode-remote.remote-ssh-explorer \
	ms-vscode-remote.remote-wsl \
	ms-vscode-remote.vscode-remote-extensionpack \
	ms-vscode.cpptools \
	octref.vetur \
	redhat.vscode-yaml \
	shd101wyy.markdown-preview-enhanced \
	shuworks.vscode-table-formatter \
	streetsidesoftware.code-spell-checker \
	sysoev.language-stylus \
	wayou.vscode-todo-highlight \
	xabikos.JavaScriptSnippets
go get -u github.com/mvdan/sh/cmd/shfmt

brew install --cask sublime-text
brew install --cask android-studio
# brew install --cask visual-studio
# brew install --cask unity
# brew install --cask wechatwebdevtools # wechat is NOT welcome to developers

# brew install --cask typora # this sucks
# brew install --cask evernote # notion is better
brew install --cask notion
# brew install --cask anki

brew install --cask skitch
# brew install --cask drawio
# giphy
# https://itunes.apple.com/us/app/giphy-capture.-the-gif-maker/id668208984

###############
# disk driver #
###############

brew install --cask osxfuse
brew install ntfs-3g

############
# database #
############

brew install freetds # For db connect

# brew install --cask sqlitebrowser
# brew install --cask robomongo
# brew install --cask sequel-pro
# brew install --cask dbeaver-community
# brew install --cask mysqlworkbench
brew install --cask azure-data-studio

################
# cli for saas #
################

brew install firebase-cli
brew install --cask google-cloud-sdk

# brew install awscli # using docker instead
brew install ask-cli

# gem install travis --no-rdoc --no-ri --user-install # https://github.com/travis-ci/travis.rb/issues/457#issue-193220429
# gem install travis --no-rdoc --no-ri # We can do this without --user-install after `gem update --system``
brew install travis

brew install drone-cli

############
# sys info #
############

brew install pstree
brew install exa --without-git
brew install procs
brew install dust
brew install tokei
# brew install htop

########################
# formatter, converter #
########################

# brew install tidy-html5
# brew install dos2unix # vscode could do this
# brew install unix2dos
brew install --cask wkhtmltopdf

brew install webp    # dwebp cwebp
brew install guetzli # JPEG encoder

brew install opencc # chinese converter, s to t or t to s
# brew install tesseract --with-all-languages # ocr

####################
# other essentials #
####################

brew install navi # helping tool to build commands in command line

# archiver
brew install p7zip
brew install --cask the-unarchiver

# FTP
# brew install --cask filezilla
brew install --cask forklift

# browsers
brew install --cask google-chrome
echo 'To restore chrome profiles, we need to restore ~/Library/"Application\ Support"/Google/Chrome/'
brew install --cask firefox
brew install --cask microsoft-edge
brew install --cask tor-browser

# social
brew install --cask telegram
brew install --cask skype
# brew install --cask electronic-wechat # native wechat upgraded! so...
# brew install --cask qq # qq is NOT welcome to developers
brew install --cask slack
brew install --cask discord
# brew install --cask microsoft-teams
brew install --cask zoom
brew install --cask splashtop-personal

# brew install --cask timing
# brew install --cask coconutbattery
brew install --cask macs-fan-control

brew install --cask cutter # decompile bin code
brew install --cask android-file-transfer
brew install --cask chrome-remote-desktop-host

# stock
brew install --cask thinkorswim

# password
brew install pwgen
# brew install --cask 1password
brew install bitwarden-cli
brew install --cask bitwarden

####################
# media essentials #
####################

# brew install --cask neteasemusic # 牆你雲音樂
# brew install --cask spotify

# brew install --cask elmedia-player
brew install --cask soda-player

# record, stream
# brew install --cask kap
brew install --cask obs # instead kap

brew install --cask calibre # ebook

# guitar, wuklele
# brew install --cask musescore

###################
# game essentials #
###################

brew install --cask battle-net
brew install --cask steam

# brew install --cask minecraft
# brew install --cask feed-the-beast

# http://www.cabextract.org.uk/
# brew install --cask cabextract

# For dos games
# brew install --cask dosbox
brew install dosbox
# brew install --cask dosbox-x # this is for 10.15
# brew install dosbox-x

# compile for dosbox
# brew install physfs

# brew install --cask windows95

# for unix* games
# brew install --cask xquartz

# for windows games
# https://wiki.winehq.org/MacOSX/Building
# brew install wine
# brew install --cask wineskin-winery

# auto clicker
curl 'http://www.beecubu.com/downloads/iMouseTrick' >~/Desktop/iMouseTrick.zip
unzip ~/Desktop/iMouseTrick.zip
mv ~/Desktop/iMouseTrick.app /Applications/

##################################
# mac enhancement, configuration #
##################################

# Preview enhancement: https://github.com/sindresorhus/quick-look-plugins
brew install \
	qlcolorcode \
	qlstephen \
	qlmarkdown \
	quicklook-json \
	qlimagesize \
	suspicious-package \
	apparency \
	quicklookase \
	qlvideo

# brew install --cask mcbopomofo
# brew install --cask openvanilla
# wget https://github.com/lukhnos/openvanilla/raw/master/DataTables/bpmf.cin <= 給繁簡互轉用

# https://github.com/herrbischoff/awesome-macos-command-line#enable-develop-menu-and-web-inspector
defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -boolean true

sudo defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
defaults write -g WebKitDeveloperExtras -bool true

defaults write -g com.apple.keyboard.fnState -int 1

# To find default app for file format, and set default app for the format
# e.q. duti -x js => duti -s com.sublimetext.3 .md all
brew install duti

# https://www.gregoryvarghese.com/reportcrash-high-cpu-disable-reportcrash/
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist

###########
# cleanup #
###########

brew cleanup -n

###############
# manual memo #
###############

# echo 'Edit the ~/.tmux.conf'
echo "mackup restore -n" to restore config or "mackup backup -n" to backup config
echo 'Do "/usr/local/opt/android-sdk/tools/android" once to download essential packages.'
echo 'Do "open /Application/Android\ Studio/" once to download sdk, Configure -> SDK Manager -> System Settings -> Android SDK -> SDK Tools -> Android SDK Command-line Tools (latest)'
