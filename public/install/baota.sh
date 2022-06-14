#!/bin/bash -e

NAME=baota
LOG_SIZE=10m
LOG_FILE=1
IMAGE=pch18/baota
DATA_DIR=/data/baota

function run_fixed() {
	docker run \
		-d \
		--restart=unless-stopped \
		--name ${NAME} \
		--net=host \
		--privileged=true \
		--shm-size=1g \
		--log-driver json-file \
		--log-opt max-size=${LOG_SIZE} \
		--log-opt max-file=${LOG_FILE} \
		-v $DATA_DIR:/www \
		-v $DATA_DIR/wwwroot:/www/wwwroot \
		$IMAGE
}

function _log() {
	echo "===>>>"
	echo "===>>> $@"
	echo "===>>>"
}

if [ -d "$DATA_DIR" ]; then
	run_fixed
else
	_log "Remember to press: \"ctrl+c\" after seeing the baota's default password"
	volume_name=baota
	docker run --rm -it \
		-v $volume_name:/www \
		$IMAGE
	_log "Initial container stopped, copy the volume to $DATA_DIR"
	cp -r /var/lib/docker/volumes/$volume_name/_data $DATA_DIR
	_log "Copied volume to $DATA_DIR"
	docker volume remove $volume_name
	_log "Volume ($volume_name) removed"
	run_fixed
	_log "Container restarted"
	sed -i -e "s/^\(\s*show_force_bind\)/\/\/\1/g" $DATA_DIR/server/panel/BTPanel/static/js/index.js
	_log "Bypassed baota signin"
	_log "Please change your admin password, select 5"
	docker exec -it $NAME bt
	_log "Remember to write the report"
fi
