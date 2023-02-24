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

function run_remote_sync_file_if_exist() {
	local f="$1"
	local source_dir="$2"
	local target_dir="$3"
	local hostname="$4"
	local ip="$5"
	if [ -f "$source_dir/$f" ]; then
		echo "===>>> ${source_dir}/$f exist, run it on the target host: ${ip}"
		ssh $hostname $target_dir/$f
	fi
}
function sync_script_to_host() {
	local source_dir="$1"
	local target_dir="$2"
	local hostname="$3"
	local more_args="$4"
	rsync -avP --delete-delay --chown=root:root \
		$more_args \
		--exclude=/.git/ \
		--exclude=/.config/ \
		${source_dir}/ ${hostname}:$target_dir/
}
function sync_config_to_host() {
	local source_dir="$1"
	local target_dir="$2"
	local hostname="$3"
	local more_args="$4"
	rsync -avP --chown=root:root \
		$more_args \
		--exclude=/.git/ \
		$source_dir/.config/ ${hostname}:$target_dir/.config/
}
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
	local delay_s="$5"
	if [ -z "$delay_s" ]; then
		delay_s=5
	fi
	local remote_f="$6"
	if [ -z "$remote_f" ]; then
		remote_f="sync.sh"
	fi

	local source_dir
	local ip=$(ssh -G $hostname | awk '/^hostname / { print $2 }')
	if [ "$?" != "0" ]; then
		die "===>>> $hostname not found."
	fi
	local port=$(ssh -G $hostname | awk '/^port / { print $2 }')
	if [ "$port" = "22" ]; then
		source_dir=$(ls -d $source_base_dir/$ip*) || true
	else
		source_dir=$(ls -d $source_base_dir/$ip\_$port*) || true
	fi
	if [ -z "$source_dir" ]; then
		# try find by hostname
		source_dir=$(ls -d $source_base_dir/*$hostname*) || true
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

	echo "After $delay_s seconds, it'll start syncing $source_dir to $hostname:$target_dir (mode: $sync_mode)"
	sleep $delay_s

	case "$sync_mode" in
	all)
		sync_script_to_host "$source_dir" "$target_dir" "$hostname" "$more_args"
		sync_config_to_host "$source_dir" "$target_dir" "$hostname" "$more_args --delete-delay"
		run_remote_sync_file_if_exist $remote_f $source_dir $target_dir $hostname $ip
		;;
	no_config)
		sync_script_to_host "$source_dir" "$target_dir" "$hostname" "$more_args"
		run_remote_sync_file_if_exist $remote_f $source_dir $target_dir $hostname $ip
		;;
	config_only)
		sync_config_to_host "$source_dir" "$target_dir" "$hostname" "$more_args"
		;;
	dry)
		sync_script_to_host "$source_dir" "$target_dir" "$hostname" "$more_args -n"
		sync_config_to_host "$source_dir" "$target_dir" "$hostname" "$more_args -n"
		;;
	default)
		sync_script_to_host "$source_dir" "$target_dir" "$hostname" "$more_args"
		sync_config_to_host "$source_dir" "$target_dir" "$hostname" "$more_args"
		run_remote_sync_file_if_exist $remote_f $source_dir $target_dir $hostname $ip
		;;
	*)
		die "Must specify the sync_mode! (should be one of all, no_config, config_only, dry, default)"
		;;
	esac
}
