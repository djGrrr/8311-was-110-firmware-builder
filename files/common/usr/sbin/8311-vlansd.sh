#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

pon_hash() {
	/usr/sbin/8311-detect-config.sh -H
}

FIX_ENABLED=$(fwenv_get_8311 "iopmask" "1")
[ "$FIX_ENABLED" -eq 0 ] 2>/dev/null && exit 0

HOOK="/ptconf/8311/vlan_fixes_hook.sh"

FIXES=""
[ "$FIX_ENABLED" -eq 1 ] && FIXES="/usr/sbin/8311-fix-vlans.sh"

LAST_HASH=""

echo "8311 VLANs daemon: start monitoring" | to_console
sleep 5
while true ; do
	CMD="$FIXES"

	if [ -n "$CMD" ] && [ -d "/sys/devices/virtual/net/gem-omci" ]; then
		HASH=$(pon_hash)
		if [ "$HASH" != "$LAST_HASH" ]; then
			if VLANS=$(flock /tmp/8311-fix-vlans.lock -c "$CMD" 2>&1); then
				LAST_HASH="$HASH"
				echo "8311 VLANs daemon: new configuration detected, ran fix-vlans script." | to_console

			fi
		fi
	fi

	sleep 5
done
