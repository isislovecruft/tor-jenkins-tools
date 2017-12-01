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

	hostname=$(hostname -f)
	if [ "$hostname" != $NODE_NAME ] ; then
		case $NODE_NAME in
			build-arm-0[0-3].torproject.org)
				echo "[$hostname] Forwarding build request to $NODE_NAME."
				set -x
				exec ssh -o BatchMode=yes -tt "$NODE_NAME" "(cd jenkins-tools && git pull) && NODE_NAME='$NODE_NAME' SUITE='$SUITE' ARCHITECTURE='$ARCHITECTURE' JOB_NAME='$JOB_NAME' jenkins-tools/$what"
				echo >&2 "Fell through exec!?"
				exit 1
				;;
			*)
				echo >&2 "Node name mismatch: We are $hostname, but NODE_NAME is $NODE_NAME."
				exit 1
				;;
		esac
	fi
}
