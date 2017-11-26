#!/bin/bash

set -e
set -u

if [ "$#" != 1 ]; then
	echo >&2 "Usage: $0 <NODE_NAME>"
	exit 1
fi

NODE_NAME=${1:-}
hostname=$(hostname -f)

pidnc1=""
pidnc2=""
pidjenkins=""

trap 'for i in "$pidnc1" "$pidnc2" "$pidjenkins"; do [ -n "$i" ] && kill "$i" || true; done' EXIT

#set -x

case "$NODE_NAME" in
	build-arm-0[0-3].torproject.org)
		echo "[$hostname] Updating jenkins-tools on $NODE_NAME:"
		ssh -o BatchMode=yes "$NODE_NAME" "(cd jenkins-tools && git pull)"

		echo "[$hostname] Starting liveness loop for $NODE_NAME"
		portlistennc=$(($RANDOM % 60000 + 1500))
		portlistenssh=$(($RANDOM % 60000 + 1500))
		portpipessh=$(($RANDOM % 60000 + 1500))
		nc -l -p $portlistennc > /dev/null & pidnc1=$!
		ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -L $portlistenssh:localhost:$portpipessh  -R $portpipessh:localhost:$portlistennc "$NODE_NAME" -f -n sleep 10
		( while : ; do echo . ; sleep 10; done | nc localhost $portlistenssh ) & pidnc2=$!

		sleep 5
		if ! kill -0 $pidnc1 || ! kill -0 $pidnc2 ; then
			echo >&2 "Slave ssh not connected."
			exit 1
		fi

		#java -jar ~/slave.jar & pidjenkins=$!
		sleep 5m & pidjenkins=$!

		rc=0
		wait -n || rc=$?

		if ! kill -0 $pidnc1 || ! kill -0 $pidnc2 ; then
			echo >&2 "ssh pipe died"
			kill $pidjenkins $pidnc2 $pidnc1 || true
			exit 1
		elif ! kill -0 $pidjenkins; then
			echo >&2 "jenkins slave terminated with $rc"
			kill $pidnc2 $pidnc1 || true
			exit $rc
		else
			echo >&2 "unlcear what died."
			kill $pidjenkins $pidnc2 $pidnc1 || true
			exit 1
		fi
		;;
	*)
		echo >&2 "$0 Unknown node name $NODE_NAME"
		exit 1
		;;
esac
