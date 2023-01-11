#!/bin/bash

# Have to setup your ~/.ssh/config first, e.q.:
#
# ```
# Host test-
# 	Hostname 1.1.1.1
# 	User root
# 	IdentityFile ~/.ssh/3cm.app/id_rsa.3cm.app
# ```

source /dev/stdin <<<"$(curl -sSL https://file.3cm.app/sh/lib.sh)"

function sync_to_host() {
	local hostname="$1"
	local sync_mode="$2"
	local deploy_dir="$3"
	if [ "$deploy_dir" == "" ]; then
		deploy_dir="/data/deploy"
	fi
	local dir
	local ip=$(ssh -G $hostname | awk '/^hostname / { print $2 }')
	if [ "$?" != "0" ]; then
		die "===>>> $hostname not found."
	fi
	local port=$(ssh -G $hostname | awk '/^port / { print $2 }')
	if [ "$port" = "22" ]; then
		dir=$(ls -d *$ip*)
	else
		dir=$(ls -d *$ip\_$port*)
	fi
	if [ "$dir" = "" ]; then
		# try find by hostname
		dir=$(ls -d *$hostname*)
		if [ "$dir" = "" ]; then
			echo >&2 "===>>> the dir of $hostname (Hostname: $ip) not found"
			exit 2
		fi
	fi
	local user=$(ssh -G $hostname | awk '/^user / { print $2 }')
	local more_args=""
	if [ "$user" = "root" ]; then
		more_args='--rsync-path="rsync"'
	else
		more_args='--rsync-path="sudo rsync"'
	fi
	case "$sync_mode" in
	all)
		rsync -avP --delete --no-owner --no-group \
			"$more_args" \
			--exclude=/.git/ \
			$(pwd)/${dir}/ ${hostname}:$deploy_dir/
		if [ -f "$(pwd)/${dir}/sync.sh" ]; then
			echo "===>>> ${dir}/sync.sh exist, run it on the host: ${ip}"
			ssh $hostname $deploy_dir/sync.sh
		fi
		;;
	without_config)
		rsync -avP --delete --no-owner --no-group \
			"$more_args" \
			--exclude=/.git/ \
			--exclude=/.config/ \
			$(pwd)/${dir}/ ${hostname}:$deploy_dir/
		if [ -f "$(pwd)/${dir}/sync.sh" ]; then
			echo "===>>> ${dir}/sync.sh exist, run it on the host: ${ip}"
			ssh $hostname $deploy_dir/sync.sh
		fi
		;;
	config_only)
		rsync -avP --no-owner --no-group \
			"$more_args" \
			--exclude=/.git/ \
			$(pwd)/.config/ ${hostname}:$deploy_dir/.config/
		;;
	*)
		rsync -avP --delete --no-owner --no-group \
			"$more_args" \
			--exclude=/.git/ \
			--exclude=/.config/ \
			$(pwd)/${dir}/ ${hostname}:/data/$NAME/
		rsync -avP --no-owner --no-group \
			"$more_args" \
			--exclude=/.git/ \
			$(pwd)/.config/ ${hostname}:$deploy_dir/.config/
		if [ -f "$(pwd)/${dir}/sync.sh" ]; then
			echo "===>>> ${dir}/sync.sh exist, run it on the host: ${ip}"
			ssh $hostname $deploy_dir/sync.sh
		fi
		;;
	esac
}
