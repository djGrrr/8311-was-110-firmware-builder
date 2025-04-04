#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

while true ; do
	PINGD_ENABLED=$(fwenv_get_8311 "pingd" "1")
	# Ping host to help management work
	PING_HOST=$(get_8311_ping_host)

	

	if [ "$PINGD_ENABLED" -ne "0" ] 2>/dev/null; then
		echo "Starting ping to: $PING_HOST" | to_console
		ping -i 1 -c 3 "$PING_HOST" &> /dev/null < /dev/null
		sleep 5
	else
		sleep 30
	fi
done
