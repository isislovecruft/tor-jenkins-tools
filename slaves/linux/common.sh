#bash

check_arg() {
	name="$1"; shift
	arg="$1"; shift

	if [ -z "${arg:-}" ]; then
		echo >&2 "No $name given."
		exit 1
	fi
	if [[ "$arg" =~ [^A-Za-z0-9.-] ]]; then
		echo >&2 "Invalid $name: $arg."
		exit 1
	fi
	if [[ "$arg" =~ \.\. ]]; then
		echo >&2 "Invalid $name: $arg."
		exit 1
	fi
}
cleanup() {
	if ! [ -z "{$chroot:-}" ]; then
		echo "Clean up build environment."
		schroot --end-session --chroot "$chroot"
	fi
}

init_args() {
	check_arg "node_name" "${NODE_NAME:-}"
	check_arg "suite" "${SUITE:-}"
	check_arg "architecture" "${ARCHITECTURE:-}"
	jobname=${JOB_NAME%%/*}
	check_arg "job's name" "${jobname:-}"
}

relay_to_remote() {
	local what
	what="$1"
	shift

	local sync_to_remote
	local sync_from_remote
	local fp

	sync_to_remote=${1:-}
	[ "$#" -gt 0 ] && shift
	sync_from_remote=${1:-}
	[ "$#" -gt 0 ] && shift

	hostname=$(hostname -f)
	if [ "$hostname" != $NODE_NAME ] ; then
		case $NODE_NAME in
			build-arm-0[0-3].torproject.org)
				if [ -n "$sync_to_remote" ]; then
					echo "[$hostname] Syncing $sync_to_remote to $NODE_NAME"
					fp=$(realpath --relative-to=/home/jenkins ./$sync_to_remote)
					ssh "$NODE_NAME" "mkdir -p $(dirname $fp)"
					rsync -ravz --delete "$sync_to_remote/." "$NODE_NAME:$fp"
				fi
				echo "[$hostname] Forwarding build request to $NODE_NAME."
				set -x
				fp=$(realpath --relative-to=/home/jenkins .)
				ssh -o BatchMode=yes -tt "$NODE_NAME" "(cd jenkins-tools && git pull) && cd '$fp' && NODE_NAME='$NODE_NAME' SUITE='$SUITE' ARCHITECTURE='$ARCHITECTURE' JOB_NAME='$JOB_NAME' ~/jenkins-tools/$what"
				if [ -n "$sync_from_remote" ]; then
					echo "[$hostname] Syncing $sync_from_remote from $NODE_NAME"
					fp=$(realpath --relative-to=/home/jenkins ./$sync_from_remote)
					rsync -ravz --delete "$NODE_NAME:$fp/." "$sync_from_remote"
				fi
				;;
			*)
				echo >&2 "Node name mismatch: We are $hostname, but NODE_NAME is $NODE_NAME."
				exit 1
				;;
		esac
	fi
}
