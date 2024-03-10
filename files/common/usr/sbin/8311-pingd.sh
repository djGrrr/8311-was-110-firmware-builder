#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

# 8311 MOD: Ping host to help management work
PING_HOST=$(get_8311_ping_host)

echo "Starting ping to: $PING_HOST" | to_console

while true ; do
	ping -i 5 "$PING_HOST" &> /dev/null < /dev/null
	sleep 5
done
