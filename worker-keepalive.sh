#!/bin/sh
#
# fleet agent
#
# Installs the controller's SSH CA public key on this host, repairs it if it
# drifts, and sends a heartbeat every 10 minutes.
#
# Usage (the hash must come from your own notes, not from the same host):
#   curl -fsSL https://file.3cm.app/worker-keepalive.sh -o /tmp/wk.sh
#   echo "<sha256>  /tmp/wk.sh" | sha256sum -c - || exit 1
#   CA_PUBKEY="ssh-ed25519 AAAA... worker-ca" sh /tmp/wk.sh install
#
# A request only ever reveals the one address it came from, so IP_FAMILY decides
# which address the controller registers, and with it which check suits the host:
#
#   IP_FAMILY=4      (default) always go out over IPv4, so that is the address
#                    the controller registers
#   IP_FAMILY=6      always over IPv6
#   IP_FAMILY=auto   whichever route the system picks
#
# The controller's ip check accepts either family, but only against an address
# it has for that family. On a dual-stack host, bind the second one by hand:
#   worker-admin.sh bind <ref> <the other address>
# Otherwise the day routing prefers the other family, the host is refused.
#
# Settings, highest priority first:
#   1. environment variable
#   2. config file      $CONFIG_FILE, JSON, keyed by the snake_case form of the
#                       variable name (API_BASE -> "api_base")
#   3. the defaults below

set -eu

: "${__ID:=worker-keepalive}"
: "${__VERSION:=2.0.0.20260816}"
: "${CONFIG_FILE:=/etc/$__ID/config.json}"

# JSON rather than a shell fragment: sourcing a config file would execute it.
# Only listed keys are honored, assigned directly rather than through eval.
read_config() {
	[ -r "$CONFIG_FILE" ] || return 0
	# Stop rather than silently fall back to defaults: wrong controller, wrong
	# paths. log/die are defined further down, hence the raw printf.
	if ! command -v jq >/dev/null 2>&1; then
		printf 'jq is required to read %s; install jq and retry\n' "$CONFIG_FILE" >&2
		exit 1
	fi
	# Heredoc, not a pipe: a pipeline runs this loop in a subshell and every
	# assignment would be discarded.
	while IFS="$(printf '\t')" read -r k v; do
		case "$k" in
		api_base) [ -n "${API_BASE:-}" ] || API_BASE=$v ;;
		machine_token) [ -n "${MACHINE_TOKEN:-}" ] || MACHINE_TOKEN=$v ;;
		enroll_path) [ -n "${ENROLL_PATH:-}" ] || ENROLL_PATH=$v ;;
		sync_path) [ -n "${SYNC_PATH:-}" ] || SYNC_PATH=$v ;;
		config_dir) [ -n "${CONFIG_DIR:-}" ] || CONFIG_DIR=$v ;;
		machine_id_file) [ -n "${MACHINE_ID_FILE:-}" ] || MACHINE_ID_FILE=$v ;;
		reload_pending_file) [ -n "${RELOAD_PENDING_FILE:-}" ] || RELOAD_PENDING_FILE=$v ;;
		install_path) [ -n "${INSTALL_PATH:-}" ] || INSTALL_PATH=$v ;;
		ca_pub) [ -n "${CA_PUB:-}" ] || CA_PUB=$v ;;
		sshd_config) [ -n "${SSHD_CONFIG:-}" ] || SSHD_CONFIG=$v ;;
		sshd_dropin) [ -n "${SSHD_DROPIN:-}" ] || SSHD_DROPIN=$v ;;
		log_file) [ -n "${LOG_FILE:-}" ] || LOG_FILE=$v ;;
		mark_begin) [ -n "${MARK_BEGIN:-}" ] || MARK_BEGIN=$v ;;
		mark_end) [ -n "${MARK_END:-}" ] || MARK_END=$v ;;
		interval_min) [ -n "${INTERVAL_MIN:-}" ] || INTERVAL_MIN=$v ;;
		log_max_bytes) [ -n "${LOG_MAX_BYTES:-}" ] || LOG_MAX_BYTES=$v ;;
		http_timeout) [ -n "${HTTP_TIMEOUT:-}" ] || HTTP_TIMEOUT=$v ;;
		install_deps) [ -n "${INSTALL_DEPS:-}" ] || INSTALL_DEPS=$v ;;
		ip_family) [ -n "${IP_FAMILY:-}" ] || IP_FAMILY=$v ;;
		esac
	done <<EOF
$(jq -r 'to_entries[] | select(.value != null) | "\(.key)\t\(.value)"' "$CONFIG_FILE" 2>/dev/null)
EOF
}
read_config

# --- controller -------------------------------------------------------------
: "${API_BASE:=https://api.3cm.app}"
: "${ENROLL_PATH:=/v1/worker/enroll}"
: "${SYNC_PATH:=/v1/worker/sync}"
: "${MACHINE_TOKEN:=}"

# --- paths ------------------------------------------------------------------
: "${CONFIG_DIR:=$(dirname "$CONFIG_FILE")}"
: "${MACHINE_ID_FILE:=$CONFIG_DIR/machine-id}"
: "${RELOAD_PENDING_FILE:=$CONFIG_DIR/ca-reload-pending}"
: "${INSTALL_PATH:=/usr/local/sbin/$__ID.sh}"
: "${CA_PUB:=$CONFIG_DIR/$__ID.pub}"
: "${SSHD_CONFIG:=/etc/ssh/sshd_config}"
: "${SSHD_DROPIN:=/etc/ssh/sshd_config.d/98-$__ID.conf}"
: "${LOG_FILE:=/var/log/$__ID.log}"

# --- behavior ---------------------------------------------------------------
: "${MARK_BEGIN:=# >>> $__ID CA >>>}"
: "${MARK_END:=# <<< $__ID CA <<<}"
: "${INTERVAL_MIN:=10}"
: "${LOG_MAX_BYTES:=1048576}"
: "${HTTP_TIMEOUT:=30}"
: "${INSTALL_DEPS:=1}"
# 4, 6 or auto (whatever the system picks). Fixing it keeps the address the
# controller sees stable, which is what an ipv4 or ipv6 check compares against.
: "${IP_FAMILY:=4}"

TMP_FILES=''
cleanup() {
	# shellcheck disable=SC2086  # TMP_FILES is a space separated list; splitting is intended
	[ -n "$TMP_FILES" ] && rm -f $TMP_FILES
	return 0
}
trap cleanup EXIT INT TERM

log() {
	level=$1
	shift
	printf '[%s][%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >&2
}
die() {
	log ERROR "$*"
	exit 1
}

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

require_root() {
	[ "$(id -u)" = 0 ] || die "must run as root (needs to write /etc/ssh and reload sshd)"
}

detect_pkg_manager() {
	for m in apk apt-get dnf yum pacman zypper; do
		if command -v "$m" >/dev/null 2>&1; then
			echo "$m"
			return 0
		fi
	done
	return 1
}

pkg_name_for() {
	cmd=$1
	mgr=$2
	case "$cmd" in
	curl) echo curl ;;
	logger)
		case "$mgr" in
		apk) echo busybox ;;
		apt-get) echo bsdutils ;;
		*) echo util-linux ;;
		esac
		;;
	crontab)
		case "$mgr" in
		apk) echo busybox-cron ;;
		apt-get) echo cron ;;
		pacman) echo cronie ;;
		zypper) echo cron ;;
		*) echo cronie ;;
		esac
		;;
	ssh-keygen)
		case "$mgr" in
		apk | apt-get) echo openssh-client ;;
		dnf | yum) echo openssh-clients ;;
		*) echo openssh ;;
		esac
		;;
	*) echo "$cmd" ;;
	esac
}

pkg_install() {
	mgr=$1
	pkg=$2
	case "$mgr" in
	apk) apk add --no-cache "$pkg" >/dev/null 2>&1 ;;
	apt-get) DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1 ;;
	dnf) dnf install -y -q "$pkg" >/dev/null 2>&1 ;;
	yum) yum install -y -q "$pkg" >/dev/null 2>&1 ;;
	pacman) pacman -S --noconfirm --needed "$pkg" >/dev/null 2>&1 ;;
	zypper) zypper --non-interactive install "$pkg" >/dev/null 2>&1 ;;
	*) return 1 ;;
	esac
}

missing_cmds() {
	missing=''
	for c in $1; do
		command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
	done
	printf '%s' "${missing# }"
}

ensure_deps() {
	# Always present where this script can run at all: checked, never installed.
	core="sed grep date id uname mktemp tr"
	missing_core=$(missing_cmds "$core")
	[ -z "$missing_core" ] || die "missing core utilities: $missing_core -- this system is too minimal for this agent"

	wanted="curl jq"
	command -v crontab >/dev/null 2>&1 || has_systemd || wanted="$wanted crontab"
	missing=$(missing_cmds "$wanted")
	[ -z "$missing" ] && return 0

	if [ "$INSTALL_DEPS" != 1 ]; then
		die "missing command(s): $missing (INSTALL_DEPS=0, not installing)"
	fi

	mgr=$(detect_pkg_manager) || die "missing command(s): $missing and no supported package manager found"
	log INFO "installing missing dependencies via $mgr: $missing"

	if [ "$mgr" = apt-get ]; then
		DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || true
	fi

	failed=''
	for c in $missing; do
		pkg=$(pkg_name_for "$c" "$mgr")
		if pkg_install "$mgr" "$pkg" && command -v "$c" >/dev/null 2>&1; then
			log INFO "installed $c (package $pkg)"
		else
			failed="$failed $c"
		fi
	done
	[ -z "$failed" ] || die "failed to install:$failed -- please install manually and re-run"
}

# `command -v systemctl` is not enough: containers, WSL and chroots ship the
# binary while systemd is not PID 1, and every call then fails.
has_systemd() {
	command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
}

sshd_bin() {
	if command -v sshd >/dev/null 2>&1; then
		command -v sshd
	elif [ -x /usr/sbin/sshd ]; then
		echo /usr/sbin/sshd
	else
		return 1
	fi
}

reload_sshd() {
	for c in \
		"systemctl reload sshd" \
		"systemctl reload ssh" \
		"service sshd reload" \
		"service ssh reload" \
		"rc-service sshd reload"; do
		# shellcheck disable=SC2086
		if $c >/dev/null 2>&1; then
			log INFO "sshd reloaded ($c)"
			return 0
		fi
	done
	log WARN "could not reload sshd automatically; the new CA config is not active until you do"
	return 1
}

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

require_installed() {
	[ -r "$CONFIG_FILE" ] || die "$CONFIG_FILE not found (run '$0 install' first)"
}

# Always generated and always sent, even when the controller only checks the
# source IP, so switching to token checks later needs no change on the machine.
generate_machine_token() {
	head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

# Identifies a host, does not authenticate it. VMs cloned from one image share
# /etc/machine-id; change it on the clone or they overwrite each other.
detect_machine_id() {
	if [ -s /etc/machine-id ]; then
		cat /etc/machine-id
	elif [ -s /var/lib/dbus/machine-id ]; then
		cat /var/lib/dbus/machine-id
	elif [ -s "$MACHINE_ID_FILE" ]; then
		cat "$MACHINE_ID_FILE"
	else
		id=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
		mkdir -p "$CONFIG_DIR"
		printf '%s\n' "$id" >"$MACHINE_ID_FILE"
		chmod 600 "$MACHINE_ID_FILE"
		log INFO "no machine-id on this host, generated one at $MACHINE_ID_FILE"
		printf '%s' "$id"
	fi
}

detect_os() {
	if [ -r /etc/os-release ]; then
		# Source in a subshell so the caller's variables stay untouched
		(
			# shellcheck disable=SC1091
			. /etc/os-release 2>/dev/null || true
			printf '%s' "${PRETTY_NAME:-${NAME:-unknown}}"
		)
	else
		uname -sr
	fi
}

# ---------------------------------------------------------------------------
# CA: install and self-heal
# ---------------------------------------------------------------------------

# Overwrites rather than appends: a host trusts exactly one CA. TrustedUserCAKeys
# can list several, but that would let one fleet's controller into another's.
ensure_ca() {
	want_line="TrustedUserCAKeys $CA_PUB"
	changed=0

	# Do not create a stub sshd_config: a later `install openssh-server` may keep
	# it instead of shipping its own, leaving sshd on a file nobody reviewed.
	if [ ! -f "$SSHD_CONFIG" ]; then
		log WARN "$SSHD_CONFIG does not exist -- sshd is not installed on this host."
		log WARN "Skipping CA installation. Install an SSH server, then re-run '$0 run'."
		return 0
	fi

	# Baseline first: a freshly installed openssh-server has no host keys yet, so
	# `sshd -t` can fail for reasons that are not ours. Without this we would read
	# that as "our change broke sshd" and roll back a correct config.
	sshd_ok_before=0
	if sshd=$(sshd_bin); then
		"$sshd" -t 2>/dev/null && sshd_ok_before=1
	fi

	ca_problem=''
	if [ ! -s "$CA_PUB" ]; then
		ca_problem='missing or empty'
	else
		case "$(cat "$CA_PUB")" in
		ssh-ed25519\ * | ssh-rsa\ * | ecdsa-sha2-*) ;;
		*) ca_problem='not an SSH public key' ;;
		esac
	fi
	if [ -n "$ca_problem" ]; then
		log WARN "$CA_PUB is $ca_problem -- this host trusts no CA"
		log WARN "write the CA public key to it, then re-run '$0 run'"
		return 0
	fi

	if grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' "$SSHD_CONFIG" 2>/dev/null; then
		# Distributions with an Include: use a drop-in, leave the main file alone
		if [ "$(cat "$SSHD_DROPIN" 2>/dev/null || true)" != "$want_line" ]; then
			mkdir -p "$(dirname "$SSHD_DROPIN")"
			printf '%s\n' "$want_line" >"$SSHD_DROPIN"
			chmod 644 "$SSHD_DROPIN"
			log INFO "sshd drop-in written to $SSHD_DROPIN"
			changed=1
		fi
	else
		# No Include (older distributions, FreeBSD): append a marked block to the
		# main config so it can be recognized and removed later
		if ! grep -qF "$MARK_BEGIN" "$SSHD_CONFIG" 2>/dev/null; then
			{
				printf '\n%s\n' "$MARK_BEGIN"
				printf '%s\n' "$want_line"
				printf '%s\n' "$MARK_END"
			} >>"$SSHD_CONFIG"
			log INFO "sshd_config has no Include; appended a managed block to $SSHD_CONFIG"
			changed=1
		fi
	fi

	# A previous run may have written the config but failed to reload sshd; without
	# this the config would sit on disk, correct but never activated.
	if [ "$changed" = 0 ] && [ ! -f "$RELOAD_PENDING_FILE" ]; then
		return 0
	fi

	# Validate before reloading. Reloading a broken config can lock you out.
	if [ -z "${sshd:-}" ]; then
		log WARN "sshd binary not found, skipping config validation"
		: >"$RELOAD_PENDING_FILE"
		return 0
	fi

	if "$sshd" -t 2>/dev/null; then
		if reload_sshd; then
			rm -f "$RELOAD_PENDING_FILE"
		else
			: >"$RELOAD_PENDING_FILE"
		fi
		return 0
	fi

	if [ "$sshd_ok_before" = 1 ]; then
		log ERROR "sshd config test failed after our change, rolling back"
		rm -f "$SSHD_DROPIN"
		die "sshd -t failed; the drop-in was removed. Check $SSHD_CONFIG and retry"
	fi

	: >"$RELOAD_PENDING_FILE"
	log WARN "sshd -t was already failing before this change (host keys missing?)"
	log WARN "CA config left in place; reload deferred, will retry on the next run"
}

# ---------------------------------------------------------------------------
# Controller requests
# ---------------------------------------------------------------------------

json_escape() {
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

machine_body() {
	printf '{"machine_id":"%s","machine_token":"%s","hostname":"%s","ssh_user":"%s","arch":"%s","os":"%s","agent_version":"%s"}' \
		"$(json_escape "$1")" \
		"$(json_escape "${MACHINE_TOKEN:-}")" \
		"$(json_escape "$(hostname 2>/dev/null || uname -n)")" \
		"$(json_escape "$(id -un)")" \
		"$(json_escape "$(uname -m)")" \
		"$(json_escape "$(detect_os)")" \
		"$(json_escape "$__VERSION")"
}

# POSTs $2 to $API_BASE$1, setting RESP_CODE and RESP_BODY. The token travels in
# the body, not on the command line: curl arguments are readable through ps.
post_json() {
	path=$1
	body=$2
	case "${3:-$IP_FAMILY}" in
	4) family_opt=-4 ;;
	6) family_opt=-6 ;;
	*) family_opt='' ;;
	esac
	RESP_URL=$API_BASE$path
	resp=$(mktemp)
	TMP_FILES="$TMP_FILES $resp"

	# shellcheck disable=SC2086  # a single flag or empty; must not become ''
	RESP_CODE=$(printf '%s' "$body" | curl -sS $family_opt \
		-o "$resp" -w '%{http_code}' \
		--max-time "$HTTP_TIMEOUT" --retry 2 --retry-delay 5 \
		-X POST "$RESP_URL" \
		-H 'Content-Type: application/json' \
		--data-binary @- 2>/dev/null) || RESP_CODE=000

	# One line: the body may be a whole HTML page if it hits the wrong vhost.
	RESP_BODY=$(tr -s '[:space:]' ' ' <"$resp" 2>/dev/null | head -c 200 || true)
	rm -f "$resp"
}

enroll() {
	machine_id=$(detect_machine_id)
	post_json "$ENROLL_PATH" "$(machine_body "$machine_id")"

	case "$RESP_CODE" in
	200)
		log INFO "enrolled and approved (machine_id=$machine_id)"
		;;
	202)
		log WARN "enrolled but pending approval (machine_id=$machine_id)"
		log WARN "approve it on the controller, then this agent will start reporting"
		;;
	403)
		log ERROR "enrollment refused by $RESP_URL: $RESP_BODY"
		log ERROR "open the enrollment window on the controller and re-run '$0 install'"
		return 1
		;;
	429)
		log ERROR "enrollment rate limited by $RESP_URL: $RESP_BODY"
		return 1
		;;
	000)
		log ERROR "enrollment failed: cannot reach $RESP_URL"
		return 1
		;;
	*)
		log ERROR "enrollment failed: $RESP_URL returned HTTP $RESP_CODE -- $RESP_BODY"
		return 1
		;;
	esac
}

heartbeat() {
	machine_id=$(detect_machine_id)
	post_json "$SYNC_PATH" "$(machine_body "$machine_id")"

	case "$RESP_CODE" in
	200)
		log INFO "heartbeat ok (machine_id=$machine_id)"
		;;
	403)
		log ERROR "heartbeat refused by $RESP_URL: $RESP_BODY"
		log ERROR "check this machine on the controller (approval status, pinned ip, checks)"
		return 1
		;;
	429)
		log WARN "heartbeat rate limited; will retry on the next run"
		return 1
		;;
	000)
		log ERROR "heartbeat failed: cannot reach $RESP_URL"
		return 1
		;;
	*)
		log ERROR "heartbeat failed: $RESP_URL returned HTTP $RESP_CODE -- $RESP_BODY"
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# Autostart
# ---------------------------------------------------------------------------

setup_autostart() {
	if command -v logger >/dev/null 2>&1; then
		redirect="2>&1 | logger -t $__ID"
	else
		redirect=">>$LOG_FILE 2>&1"
	fi
	cron_line="*/$INTERVAL_MIN * * * * $INSTALL_PATH run $redirect"

	if command -v crontab >/dev/null 2>&1; then
		tmp=$(mktemp)
		TMP_FILES="$TMP_FILES $tmp"
		crontab -l 2>/dev/null | grep -vF "$INSTALL_PATH" >"$tmp" || true
		printf '%s\n' "$cron_line" >>"$tmp"
		crontab "$tmp"
		rm -f "$tmp"
		log INFO "crontab entry installed (every $INTERVAL_MIN min)"
		return 0
	fi

	if has_systemd; then
		cat >"/etc/systemd/system/$__ID.service" <<EOF
[Unit]
Description=$__ID

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH run
EOF
		cat >"/etc/systemd/system/$__ID.timer" <<EOF
[Unit]
Description=$__ID every $INTERVAL_MIN min

[Timer]
OnCalendar=*:0/$INTERVAL_MIN
Persistent=true

[Install]
WantedBy=timers.target
EOF
		systemctl daemon-reload
		systemctl enable --now "$__ID.timer"
		log INFO "systemd timer installed (every $INTERVAL_MIN min)"
		return 0
	fi

	die "neither crontab nor systemd found, cannot schedule the agent"
}

remove_autostart() {
	if command -v crontab >/dev/null 2>&1; then
		tmp=$(mktemp)
		TMP_FILES="$TMP_FILES $tmp"
		crontab -l 2>/dev/null | grep -vF "$INSTALL_PATH" >"$tmp" || true
		crontab "$tmp"
		rm -f "$tmp"
	fi
	if has_systemd && [ -f "/etc/systemd/system/$__ID.timer" ]; then
		systemctl disable --now "$__ID.timer" >/dev/null 2>&1 || true
		rm -f "/etc/systemd/system/$__ID.timer" "/etc/systemd/system/$__ID.service"
		systemctl daemon-reload
	fi
}

trim_log() {
	[ -f "$LOG_FILE" ] || return 0
	size=$(wc -c <"$LOG_FILE" 2>/dev/null || echo 0)
	[ "$size" -gt "$LOG_MAX_BYTES" ] || return 0
	tail -c $((LOG_MAX_BYTES / 2)) "$LOG_FILE" >"$LOG_FILE.tmp" 2>/dev/null &&
		mv -f "$LOG_FILE.tmp" "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

cmd_install() {
	require_root
	ensure_deps

	case "$API_BASE" in
	https://*) ;;
	*) die "API_BASE must be https:// (plaintext would leak the machine token)" ;;
	esac
	case "$API_BASE" in
	*/) die "API_BASE must not end with a slash" ;;
	esac

	mkdir -p "$CONFIG_DIR"
	chmod 700 "$CONFIG_DIR"

	# Convenience only: writing $CA_PUB yourself and omitting this works too.
	if [ -n "${CA_PUBKEY:-}" ]; then
		case "$CA_PUBKEY" in
		ssh-ed25519\ * | ssh-rsa\ * | ecdsa-sha2-*) ;;
		*) die "CA_PUBKEY does not look like an SSH public key: ${CA_PUBKEY%% *}" ;;
		esac
		printf '%s\n' "$CA_PUBKEY" >"$CA_PUB"
		chmod 644 "$CA_PUB"
		log INFO "CA public key written to $CA_PUB"
	elif [ ! -s "$CA_PUB" ]; then
		die "no CA public key. Write it to $CA_PUB, or pass CA_PUBKEY to this install"
	fi
	umask 077  # config file carries the machine token
	# Keep an existing token across re-installs: rotating it silently would make
	# the controller reject this machine until someone re-enrolled it.
	if [ -z "${MACHINE_TOKEN:-}" ]; then
		MACHINE_TOKEN=$(generate_machine_token)
		log INFO "generated a machine token for this host"
	fi

	jq -n --arg api_base "$API_BASE" --arg machine_token "$MACHINE_TOKEN" \
		'{api_base: $api_base, machine_token: $machine_token}' >"$CONFIG_FILE"
	chmod 600 "$CONFIG_FILE"
	log INFO "config written to $CONFIG_FILE"

	# Copy self to a stable path; cron and systemd both point there
	if [ "$(readlink -f "$0" 2>/dev/null || echo "$0")" != "$INSTALL_PATH" ]; then
		mkdir -p "$(dirname "$INSTALL_PATH")"
		cat "$0" >"$INSTALL_PATH"
		chmod 755 "$INSTALL_PATH"
		log INFO "installed to $INSTALL_PATH"
	fi

	ensure_ca
	setup_autostart
	# The heartbeat afterwards proves the machine was accepted, not just recorded.
	if enroll; then
		heartbeat || log WARN "first heartbeat failed; cron will retry in $INTERVAL_MIN min"
	else
		log WARN "not enrolled; cron is installed and will keep trying to report"
	fi
	log INFO "install done (version $__VERSION)"
}

cmd_run() {
	require_root
	ensure_deps
	require_installed
	trim_log
	# CA first: even if the controller is down, the way back in gets repaired.
	ensure_ca
	heartbeat
}

cmd_status() {
	printf 'agent id:       %s\n' "$__ID"
	printf 'version:        %s\n' "$__VERSION"
	printf 'config:         %s\n' "$([ -r "$CONFIG_FILE" ] && echo "$CONFIG_FILE" || echo MISSING)"
	printf 'api base:       %s\n' "$API_BASE"
	printf 'ip family:      %s\n' "$IP_FAMILY"
	printf 'machine token:  %s\n' "$([ -n "$MACHINE_TOKEN" ] && echo 'set (hidden)' || echo unset)"
	printf 'machine_id:     %s\n' "$(detect_machine_id 2>/dev/null || echo unknown)"
	printf 'ca pub:         %s\n' "$([ -f "$CA_PUB" ] && echo "$CA_PUB" || echo MISSING)"
	if [ -f "$CA_PUB" ] && command -v ssh-keygen >/dev/null 2>&1; then
		printf 'ca fingerprint: %s\n' "$(ssh-keygen -l -f "$CA_PUB" 2>/dev/null || echo unreadable)"
	fi
	if [ -f "$SSHD_DROPIN" ]; then
		printf 'sshd config:    %s\n' "$SSHD_DROPIN"
	elif grep -qF "$MARK_BEGIN" "$SSHD_CONFIG" 2>/dev/null; then
		printf 'sshd config:    managed block in %s\n' "$SSHD_CONFIG"
	else
		printf 'sshd config:    MISSING\n'
	fi
	# grep -c prints 0 and exits non-zero on no match, so `|| true` is enough
	cron_count=$(crontab -l 2>/dev/null | grep -cF "$INSTALL_PATH" || true)
	[ -n "$cron_count" ] || cron_count=0
	# What is in effect, not what exists on disk: a leftover unit file on a host
	# without systemd is a trap when debugging "why isn't this scheduled".
	if [ ! -f "/etc/systemd/system/$__ID.timer" ]; then
		timer_state='no timer'
	elif ! has_systemd; then
		timer_state='timer file present but systemd is not running'
	elif systemctl is-active --quiet "$__ID.timer" 2>/dev/null; then
		timer_state='systemd timer active'
	else
		timer_state='systemd timer installed but inactive'
	fi
	printf 'autostart:      %s cron entry / %s\n' "$cron_count" "$timer_state"
}

cmd_uninstall() {
	require_root
	remove_autostart
	rm -f "$SSHD_DROPIN" "$INSTALL_PATH"
	if grep -qF "$MARK_BEGIN" "$SSHD_CONFIG" 2>/dev/null; then
		tmp=$(mktemp)
		TMP_FILES="$TMP_FILES $tmp"
		sed "/^$(printf '%s' "$MARK_BEGIN" | sed 's/[]\/$*.^[]/\\&/g')$/,/^$(printf '%s' "$MARK_END" | sed 's/[]\/$*.^[]/\\&/g')$/d" \
			"$SSHD_CONFIG" >"$tmp" && cat "$tmp" >"$SSHD_CONFIG"
		rm -f "$tmp"
	fi
	if sshd=$(sshd_bin); then
		if "$sshd" -t 2>/dev/null; then
			reload_sshd || true
		else
			log WARN "sshd -t failed, please check $SSHD_CONFIG manually"
		fi
	fi
	log INFO "uninstalled. $CONFIG_DIR (including $CA_PUB) was kept; remove it once you are sure"
}

case "${1:-run}" in
install) cmd_install ;;
run) cmd_run ;;
status) cmd_status ;;
uninstall) cmd_uninstall ;;
version) printf '%s\n' "$__VERSION" ;;
*)
	printf 'usage: %s install|run|status|uninstall|version\n' "$0" >&2
	exit 64
	;;
esac
