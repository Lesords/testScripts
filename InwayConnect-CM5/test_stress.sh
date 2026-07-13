#!/bin/bash

GATEWAY=$(ip route | awk '/default/ {print $3; exit}')

cleanup()
{
	kill $STRESS_PID $PING_PID 2>/dev/null
	wait 2>/dev/null
	exit 0
}

trap cleanup INT TERM

while [ 1 ]
do
	stress --cpu 4 --timeout 30s
	# stress --cpu 4 --io 4 --vm 2 --vm-bytes 128M --timeout 30s
	# sleep 1
done &
STRESS_PID=$!

while [ 1 ]
do
	ping -c 5 -W 1 $GATEWAY
	sleep 1
done &
PING_PID=$!

wait
