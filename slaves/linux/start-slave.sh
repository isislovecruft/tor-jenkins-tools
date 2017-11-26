#!/bin/bash

set -e
set -u

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
check_arg "node_name" "${NODE_NAME:-}"
hostname=$(hostname -f)


cd ~/jenkins-tools
flock -w 30 . git pull
cd -

if [ "$hostname" = "$NODE_NAME" ] ; then
	exec java -jar ~/slave.jar
else
	case "$NODE_NAME" in
		build-arm-0[0-3].torproject.org)
			echo "[$hostname] Updating jenkins-tools on $NODE_NAME."
			ssh  -o BatchMode=yes -tt "$NODE_NAME" "(cd jenkins-tools && git pull)"

			portlistennc=$(($RANDOM % 60000 + 1500))
			portlistenssh=$(($RANDOM % 60000 + 1500))
			portpipessh=$(($RANDOM % 60000 + 1500))
			nc -l -p $portlistennc > /dev/null & pidnc1=$!
			ssh -o ExitOnForwardFailure=yes -L $portlistenssh:localhost:$portpipessh  -R $portpipessh:localhost:$portlistennc build-arm-01.torproject.org -f -n sleep 10
			( while : ; do echo . ; sleep 10; done | nc localhost $portlistenssh) & pidnc2=$!

			sleep 5
			if ! kill -0 $pidnc1 || ! kill -0 $pidnc2 ; then
				echo >&2 "Slave ssh not connected."
				exit 1
			fi

			java -jar ~/slave.jar & pidjenkins=$!

			rc=0
			wait -n || rc=$?

			if ! kill -0 $pidnc1 || ! kill -0 $pidnc2 ; then
				echo >&2 "ssh pipe died"
				kill $pidjenkins $pidnc2 $pidnc1
				exit 1
			elif ! kill -0 $pidjenkins; then
				echo >&2 "jenkins slave terminated with $rc"
				kill $pidnc2 $pidnc1
				exit $rc
			else
				echo >&2 "unlcear what died."
				kill $pidjenkins $pidnc2 $pidnc1
				exit 1
			fi
			;;
		*)
			echo >&2 "Node name mismatch: We are $hostname, but NODE_NAME is $NODE_NAME."
			exit 1
			;;
	esac
else
fi
