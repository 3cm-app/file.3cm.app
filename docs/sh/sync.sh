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
	local source_base_dir="$3"
	if [[ -z "$source_base_dir" ]]; then
		source_base_dir="$(pwd)"
	fi
	local target_dir="$4"
	if [ -z "$target_dir" ]; then
		target_dir="/data/deploy"
	fi
	local source_dir
	local ip=$(ssh -G $hostname | awk '/^hostname / { print $2 }')
	if [ "$?" != "0" ]; then
		die "===>>> $hostname not found."
	fi
	local port=$(ssh -G $hostname | awk '/^port / { print $2 }')
	if [ "$port" = "22" ]; then
		source_dir=$(ls -d $source_base_dir/$ip*)
	else
		source_dir=$(ls -d $source_base_dir/$ip\_$port*)
	fi
	if [ -z "$source_dir" ]; then
		# try find by hostname
		source_dir=$(ls -d $source_base_dir/*$hostname*)
		if [ -z "$source_dir" ]; then
			die "===>>> the dir of $hostname (Hostname: $ip) not found"
		fi
	fi
	local user=$(ssh -G $hostname | awk '/^user / { print $2 }')
	local more_args=""
	if [ "$user" = "root" ]; then
		more_args='--rsync-path="rsync"'
	else
		more_args='--rsync-path="sudo rsync"'
	fi
	echo "After 3 seconds, it'll start syncing $source_dir to $hostname:$target_dir"
	sleep 3
	case "$sync_mode" in
	all)
		rsync -avP --delete --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			${dir}/ ${hostname}:$target_dir/
		if [ -f "$(pwd)/${dir}/sync.sh" ]; then
			echo "===>>> ${dir}/sync.sh exist, run it on the host: ${ip}"
			ssh $hostname $target_dir/sync.sh
		fi
		;;
	without_config)
		rsync -avP --delete --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			--exclude=/.config/ \
			${source_dir}/ ${hostname}:$target_dir/
		if [ -f "${source_dir}/sync.sh" ]; then
			echo "===>>> ${source_dir}/sync.sh exist, run it on the host: ${ip}"
			ssh $hostname $target_dir/sync.sh
		fi
		;;
	config_only)
		rsync -avP --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			$source_dir/.config/ ${hostname}:$target_dir/.config/
		;;
	dry)
		rsync -n -avP --delete --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			--exclude=/.config/ \
			$source_dir/ ${hostname}:$target_dir/
		rsync -n -avP --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			$source_dir/.config/ ${hostname}:$target_dir/.config/
		;;
	default)
		rsync -avP --delete --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			--exclude=/.config/ \
			$source_dir/ ${hostname}:$target_dir/
		rsync -avP --chown=root:root \
			"$more_args" \
			--exclude=/.git/ \
			$source_dir/.config/ ${hostname}:$target_dir/.config/
		if [ -f "$source_dir/sync.sh" ]; then
			echo "===>>> ${source_dir}/sync.sh exist, run it on the host: ${ip}"
			ssh $hostname $target_dir/sync.sh
		fi
		;;
	*)
		die "must specify the sync_mode!"
		;;
	esac
}
