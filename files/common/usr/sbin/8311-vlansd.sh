#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

pon_hash() {
	/root/8311-detect-config.sh -H
}

FIX_ENABLED=$(fwenv_get_8311 "fix_vlans")
if [ "$FIX_ENABLED" -eq 0 ] 2>/dev/null; then
	exit 0
fi

LAST_HASH=""

echo "8311 VLANs daemon: start monitoring" | to_console
while true ; do
	if [ -d "/sys/devices/virtual/net/gem-omci" ]; then
		HASH=$(pon_hash)
		if [ "$HASH" != "$LAST_HASH" ] && VLANS=$(flock /tmp/8311-fix-vlans.lock /root/8311-fix-vlans.sh 2>&1); then
			LAST_HASH="$HASH"
			echo "8311 VLANs daemon: new configuration detected, ran fix-vlans script:" | to_console
			echo "$VLANS" | to_console
		fi
	fi

	sleep 5
done
